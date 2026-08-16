import Alamofire
import Foundation
import Logging
import Testing
@testable import Networking

/// `Log.bootstrap` 은 전역 백엔드를 갈아끼우므로 이 스위트는 **반드시 직렬**로 돌아야 한다.
/// 병렬로 돌면 다른 스위트의 로그를 삼키거나 백엔드가 뒤바뀐다.
final class SpyLogHandler: LogHandler, @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [(level: LogLevel, message: String, metadata: [String: String])] = []

    func log(_ level: LogLevel, message: String, metadata: [String: String],
             file: String, function: String, line: UInt) {
        lock.withLock { entries.append((level, message, metadata)) }
    }

    var all: [(level: LogLevel, message: String, metadata: [String: String])] {
        lock.withLock { entries }
    }

    func first(containing text: String) -> (level: LogLevel, message: String, metadata: [String: String])? {
        all.first { $0.message.contains(text) }
    }
}

@Suite("로깅", .serialized)
struct NetworkLoggerTests {
    /// 프로덕션과 동일하게 `NetworkLogger` 를 붙인 클라이언트. 이걸 안 붙이면
    /// 로거가 한 번도 실행되지 않아 배선이 끊겨도 테스트가 통과한다(실제로 그랬다).
    private func makeLoggingSUT() -> (URLSessionHTTPClient, URLProtocolStub.Handle, SpyLogHandler) {
        let spy = SpyLogHandler()
        Log.bootstrap(spy)
        let (configuration, handle) = URLProtocolStub.makeSession()
        let session = Session(configuration: configuration, eventMonitors: [NetworkLogger()])
        let sut = URLSessionHTTPClient(baseURL: URL(string: "https://api.gguk.org")!, session: session)
        return (sut, handle, spy)
    }

    /// EventMonitor 는 자기 큐에서 비동기로 돌아 응답 반환보다 늦을 수 있다.
    private func waitForLog(_ spy: SpyLogHandler, containing text: String) async -> Bool {
        for _ in 0..<50 {
            if spy.first(containing: text) != nil { return true }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return false
    }

    @Test("성공 요청은 요청·응답 두 줄을 남긴다")
    func logsRequestAndResponse() async throws {
        let (sut, stub, spy) = makeLoggingSUT()
        stub.stub.body = Data(#"{"data":[]}"#.utf8)

        _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms"))

        #expect(await waitForLog(spy, containing: "→ 요청"))
        #expect(await waitForLog(spy, containing: "← 응답"))

        let response = try #require(spy.first(containing: "← 응답"))
        #expect(response.metadata["status"] == "200")
        #expect(response.metadata["elapsed"] != nil)
    }

    @Test("실패 응답은 warning 으로 남는다")
    func logsFailureAsWarning() async throws {
        let (sut, stub, spy) = makeLoggingSUT()
        stub.stub.statusCode = 500

        _ = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

        #expect(await waitForLog(spy, containing: "← 응답 실패"))
        let entry = try #require(spy.first(containing: "← 응답 실패"))
        #expect(entry.level == .warning)
        #expect(entry.metadata["status"] == "500")
    }

    @Test("5xx 응답 본문을 로그에 남긴다 — 장애 원인 추적의 유일한 단서다")
    func logsServerErrorBody() async throws {
        let (sut, stub, spy) = makeLoggingSUT()
        stub.stub.statusCode = 500
        stub.stub.body = Data(#"{"errorCode":"DB_TIMEOUT","message":"조회 지연"}"#.utf8)

        _ = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

        let entry = try #require(spy.first(containing: "서버 오류 본문"))
        #expect(entry.metadata["preview"]?.contains("DB_TIMEOUT") == true)
    }

    @Test("본문이 있는데 계약이 아닌 401 은 로그로 드러난다")
    func logsBrokenUnauthorizedBody() async throws {
        let (sut, stub, spy) = makeLoggingSUT()
        stub.stub.statusCode = 401
        stub.stub.body = Data("<html>Gateway login</html>".utf8)

        _ = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

        let entry = try #require(spy.first(containing: "약속 포맷이 아님"))
        #expect(entry.metadata["status"] == "401")
    }

    @Test("어떤 로그에도 Authorization 이 남지 않는다")
    func neverLogsAuthorization() async throws {
        let (sut, stub, spy) = makeLoggingSUT()
        stub.stub.body = Data(#"{"data":[]}"#.utf8)

        _ = try await sut.request(Endpoint<[RoomDTO]>(
            path: "api/v1/rooms",
            headers: ["Authorization": "Bearer super-secret-token"]
        ))
        _ = await waitForLog(spy, containing: "← 응답")

        let dump = spy.all.map { "\($0.message) \($0.metadata)" }.joined()
        #expect(!dump.contains("super-secret-token"))
        #expect(!dump.contains("Authorization"))
    }
}
