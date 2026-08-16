import Alamofire
import Foundation
import Logging
import Testing
@testable import Networking

/// `Log.bootstrap` 은 **전역** 백엔드를 갈아끼운다. `.serialized` 는 이 스위트 안만 직렬화할 뿐
/// 다른 스위트와의 병렬 실행은 막지 못하므로, spy 에는 다른 테스트의 로그가 섞여 들어온다.
/// 그래서 테스트마다 **고유 경로**를 쓰고 그 경로의 로그만 골라 본다.
final class SpyLogHandler: LogHandler, @unchecked Sendable {
    struct Entry {
        let level: LogLevel
        let message: String
        let metadata: [String: String]
    }

    private let lock = NSLock()
    private var entries: [Entry] = []

    func log(_ level: LogLevel, message: String, metadata: [String: String],
             file: String, function: String, line: UInt) {
        lock.withLock { entries.append(Entry(level: level, message: message, metadata: metadata)) }
    }

    /// 이 테스트가 쓴 경로의 로그만. 다른 스위트가 남긴 같은 이름의 로그를 잡지 않는다.
    func entries(forPath path: String) -> [Entry] {
        lock.withLock { entries }.filter {
            ($0.metadata["path"] ?? $0.metadata["url"] ?? "").contains(path)
        }
    }

    /// 메시지 **정확 일치**. `contains` 로 찾으면 "← 응답" 이 "← 응답 실패" 까지 잡는다.
    func entry(_ message: String, forPath path: String) -> Entry? {
        entries(forPath: path).first { $0.message == message }
    }
}

/// 전역 백엔드는 타깃 전체에서 한 번만 설치한다 — 테스트마다 갈아끼우면 서로를 무력화한다.
private let sharedSpy: SpyLogHandler = {
    let spy = SpyLogHandler()
    Log.bootstrap(spy)
    return spy
}()

@Suite("로깅")
struct NetworkLoggerTests {
    /// 프로덕션과 동일하게 `NetworkLogger` 를 붙인 클라이언트. 이걸 안 붙이면
    /// 로거가 한 번도 실행되지 않아 배선이 끊겨도 테스트가 통과한다(실제로 그랬다).
    private func makeLoggingSUT(
        interceptor: (any RequestInterceptor)? = nil
    ) -> (URLSessionHTTPClient, URLProtocolStub.Handle, SpyLogHandler, String) {
        let spy = sharedSpy
        let path = "api/v1/probe/\(UUID().uuidString)"
        let (configuration, handle) = URLProtocolStub.makeSession()
        let session = Session(configuration: configuration, interceptor: interceptor, eventMonitors: [NetworkLogger()])
        let sut = URLSessionHTTPClient(baseURL: URL(string: "https://api.gguk.org")!, session: session)
        return (sut, handle, spy, path)
    }

    /// EventMonitor 는 자기 큐에서 비동기로 돌아 응답 반환보다 늦을 수 있다.
    private func waitFor(
        _ message: String, path: String, in spy: SpyLogHandler
    ) async -> SpyLogHandler.Entry? {
        for _ in 0..<100 {
            if let entry = spy.entry(message, forPath: path) { return entry }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return nil
    }

    @Test("성공 요청은 요청·응답 두 줄을 남긴다")
    func logsRequestAndResponse() async throws {
        let (sut, stub, spy, path) = makeLoggingSUT()
        stub.stub.body = Data(#"{"data":[]}"#.utf8)

        _ = try await sut.request(Endpoint<[RoomDTO]>(path: path))

        #expect(await waitFor("→ 요청", path: path, in: spy) != nil)
        let response = try #require(await waitFor("← 응답", path: path, in: spy))
        #expect(response.metadata["status"] == "200")
        #expect(response.level == .debug)
    }

    @Test("실패 응답은 warning 으로 남는다")
    func logsFailureAsWarning() async throws {
        let (sut, stub, spy, path) = makeLoggingSUT()
        stub.stub.statusCode = 500

        _ = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: path)) }

        let entry = try #require(await waitFor("← 응답 실패", path: path, in: spy))
        #expect(entry.level == .warning)
        #expect(entry.metadata["status"] == "500")
    }

    @Test("5xx 응답 본문을 로그에 남긴다 — 장애 원인 추적의 유일한 단서다")
    func logsServerErrorBody() async throws {
        let (sut, stub, spy, path) = makeLoggingSUT()
        stub.stub.statusCode = 500
        stub.stub.body = Data(#"{"errorCode":"DB_TIMEOUT","message":"조회 지연"}"#.utf8)

        _ = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: path)) }

        let entry = try #require(await waitFor("서버 오류 본문", path: path, in: spy))
        #expect(entry.metadata["preview"]?.contains("DB_TIMEOUT") == true)
    }

    @Test("본문이 있는데 계약이 아닌 401 은 로그로 드러난다")
    func logsBrokenUnauthorizedBody() async throws {
        let (sut, stub, spy, path) = makeLoggingSUT()
        stub.stub.statusCode = 401
        stub.stub.body = Data("<html>Gateway login</html>".utf8)

        _ = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: path)) }

        let entry = try #require(await waitFor("에러 응답이 약속 포맷이 아님", path: path, in: spy))
        #expect(entry.metadata["status"] == "401")
    }

    // 재시도가 로그에 안 남으면 최대 20초 지연의 원인을 설명할 수 없다.
    // 로깅 스위트는 interceptor 없는 세션을, 재시도 스위트는 로거 없는 세션을 쓰기 때문에
    // 이 조합(로거 + 재시도)이 없으면 "↻ 재시도" 는 프로덕션에서 처음 실행된다.
    @Test("재시도가 일어나면 로그에 남는다")
    func logsRetry() async throws {
        let (sut, stub, spy, path) = makeLoggingSUT(interceptor: testRetryPolicy)
        stub.stub.statusCode = 503

        _ = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: path)) }

        let entry = try #require(await waitFor("↻ 재시도", path: path, in: spy))
        #expect(entry.metadata["attempt"] == "2")
    }

    @Test("어떤 로그에도 Authorization 이 남지 않는다")
    func neverLogsAuthorization() async throws {
        let (sut, stub, spy, path) = makeLoggingSUT()
        stub.stub.body = Data(#"{"data":[]}"#.utf8)

        _ = try await sut.request(Endpoint<[RoomDTO]>(
            path: path,
            headers: ["Authorization": "Bearer super-secret-token"]
        ))
        _ = await waitFor("← 응답", path: path, in: spy)

        let dump = spy.entries(forPath: path).map { "\($0.message) \($0.metadata)" }.joined()
        #expect(!dump.contains("super-secret-token"))
        #expect(!dump.contains("Authorization"))
    }
}
