import Alamofire
import Foundation
import Logging
import Testing
@testable import Networking

/// `Log.bootstrap` 은 **전역** 백엔드를 갈아끼운다. `.serialized` 는 이 스위트 안만 직렬화할 뿐
/// 다른 스위트와의 병렬 실행은 막지 못하므로, spy 에는 다른 테스트의 로그가 섞여 들어온다.
/// 그래서 테스트마다 **고유 경로**를 쓰고 그 경로의 로그만 골라 본다.
@Suite("로깅")
struct NetworkLoggerTests {
    /// 프로덕션과 동일하게 `NetworkLogger` 를 붙인 클라이언트. 이걸 안 붙이면
    /// 로거가 한 번도 실행되지 않아 배선이 끊겨도 테스트가 통과한다(실제로 그랬다).
    private func makeLoggingSUT(
        interceptor: (any RequestInterceptor)? = nil
    ) -> (URLSessionHTTPClient, URLProtocolStub.Handle, SpyLogHandler, String) {
        let spy = sharedSpy
        // 마스킹 대상이 되지 않는 고유 세그먼트를 쓴다 — UUID 는 릴리즈에서 `***` 로 가려져
        // 자기 로그를 골라낼 수 없다(그게 LogRedaction 의 의도된 동작이다).
        let path = "api/v1/probe/\(uniqueToken())"
        let (configuration, handle) = URLProtocolStub.makeSession()
        let session = Session(configuration: configuration, interceptor: interceptor, eventMonitors: [NetworkLogger()])
        let sut = URLSessionHTTPClient(baseURL: URL(string: "https://stub.invalid")!, session: session)
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
        // 재시도가 없었으면 시도는 1회. `attempts` 를 지워도 통과하는 걸 막는다.
        #expect(entry.metadata["attempts"] == "1")
        // elapsed 는 마지막 시도만이 아니라 전체 소요여야 한다(allMetrics 합계).
        // 0 이면 metrics 를 못 읽은 것이라 "왜 느렸나" 조사에서 네트워크가 제외된다.
        let elapsed = Double(entry.metadata["elapsed"]?.replacingOccurrences(of: "s", with: "") ?? "")
        #expect((elapsed ?? 0) > 0)
    }

    @Test("5xx 응답 본문을 로그에 남긴다 — 장애 원인 추적의 유일한 단서다")
    func logsServerErrorBody() async throws {
        let (sut, stub, spy, path) = makeLoggingSUT()
        stub.stub.statusCode = 500
        stub.stub.body = Data(#"{"errorCode":"DB_TIMEOUT","message":"조회 지연"}"#.utf8)

        _ = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: path)) }

        let entry = try #require(await waitFor("서버 오류 본문", path: path, in: spy))
        // 본문 내용은 DEBUG 에만 남는다. 릴리즈는 크기만 — 서버 에러 본문에 요청 에코·닉네임이
        // 실릴 수 있어 기기 로그에 평문으로 쌓이면 안 된다(LogRedaction).
        if LogRedaction.isDebugBuild {
            #expect(entry.metadata["preview"]?.contains("DB_TIMEOUT") == true)
        } else {
            #expect(entry.metadata["preview"] == nil)
            #expect(entry.metadata["bodyBytes"] != nil)
        }
    }

    // 스펙상 4xx 는 전부 Error 스키마(errorCode·message 필수)를 쓴다.
    // 그래서 **본문이 비어 있어도 계약 위반**이고, 401 도 예외가 아니다.
    // "인증 미들웨어가 본문 없이 던지더라" 는 관측된 적 없는 실무 예상일 뿐이었다.
    @Test("계약을 어긴 401 은 본문 유무와 무관하게 로그로 드러난다", arguments: [
        Data("<html>Gateway login</html>".utf8),
        Data(),
    ])
    func logsContractViolatingUnauthorized(_ body: Data) async throws {
        let (sut, stub, spy, path) = makeLoggingSUT()
        stub.stub.statusCode = 401
        stub.stub.body = body

        _ = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: path)) }

        let entry = try #require(await waitFor("에러 응답이 약속 포맷이 아님", path: path, in: spy))
        #expect(entry.metadata["status"] == "401")
    }

    @Test("재시도가 일어나면 로그에 남는다")
    func logsRetry() async throws {
        let (sut, stub, spy, path) = makeLoggingSUT(interceptor: testRetryPolicy)
        stub.stub.statusCode = 503

        _ = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: path)) }

        let entry = try #require(await waitFor("↻ 재시도", path: path, in: spy))
        #expect(entry.metadata["attempt"] == "2")

        // 응답 로그의 attempts 도 재시도를 반영해야 한다 — 사용자가 기다린 시간은
        // 두 시도의 합인데, 마지막 시도만 재면 조사자가 네트워크를 용의선상에서 뺀다.
        let response = try #require(await waitFor("← 응답 실패", path: path, in: spy))
        #expect(response.metadata["attempts"] == "2")
    }

    // 취소는 화면 이탈마다 일어난다. warning 이면 릴리즈 로그가 취소로 뒤덮여
    // 진짜 실패가 묻힌다.
    @Test("취소는 실패가 아니라 debug 로 남는다")
    func logsCancellationAsDebug() async throws {
        let (sut, stub, spy, path) = makeLoggingSUT()
        stub.stub.suspends = true

        let task = Task { _ = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: path)) } }
        _ = await poll { !stub.recorded.isEmpty }
        task.cancel()
        await task.value

        let entry = try #require(await waitFor("← 취소", path: path, in: spy))
        #expect(entry.level == .debug)
        #expect(spy.entry("← 응답 실패", forPath: path) == nil)
    }

    // 전송 오류를 `String(describing:)` 으로 찍으면 URLError userInfo 의
    // `NSErrorFailingURLKey` 를 통해 **전체 URL 이 통째로 들어간다**. 초대 코드가 경로에
    // 있으므로 LogRedaction 으로 가려놓고 옆에서 새는 꼴이 된다. 실제로 그랬던 적이 있다.
    @Test("전송 오류 로그에 URL·초대 코드가 새지 않는다")
    func transportErrorLogDoesNotLeakURL() async throws {
        let spy = sharedSpy
        let secretPath = "api/v1/invitations/\(uniqueToken())"
        let (configuration, stub) = URLProtocolStub.makeSession()
        stub.stub.error = URLError(.timedOut, userInfo: [
            NSURLErrorFailingURLErrorKey: URL(string: "https://stub.invalid/\(secretPath)")!,
        ])
        let session = Session(configuration: configuration, eventMonitors: [NetworkLogger()])
        let sut = URLSessionHTTPClient(baseURL: URL(string: "https://stub.invalid")!, session: session)

        _ = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: secretPath)) }

        let entry = try #require(spy.entries(forPath: secretPath).first { $0.message == "전송 실패" })
        let dump = "\(entry.message) \(entry.metadata)"
        #expect(!dump.contains("NSErrorFailingURL"))
        #expect(entry.metadata["urlErrorCode"] == String(URLError.Code.timedOut.rawValue))
        #expect(entry.metadata["reason"] == "sessionTaskFailed")
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

    // DEBUG 로그는 본문을 그대로 싣는다. 상한이 없으면 목록 응답 하나가 수백 KB 를
    // 로그 파이프에 밀어 넣어, 정작 필요한 앞뒤 줄이 밀려 사라진다.
    @Test("DEBUG 본문 로그는 2048 바이트에서 끊는다")
    func truncatesResponseBodyLog() async throws {
        let (sut, stub, spy, path) = makeLoggingSUT()
        let filler = String(repeating: "A", count: 5_000)
        stub.stub.body = Data(#"{"data":[],"note":"\#(filler)"}"#.utf8)

        _ = try await sut.request(Endpoint<[RoomDTO]>(path: path))

        let entry = try #require(await waitFor("← 응답", path: path, in: spy))
        if LogRedaction.isDebugBuild {
            #expect(entry.metadata["body"]?.count == 2048)
        } else {
            #expect(entry.metadata["body"] == nil)   // 릴리즈는 본문을 아예 싣지 않는다
        }
    }
}
