import Alamofire
import Foundation
import Testing
@testable import Networking

private struct BadBody: Encodable, Sendable {
    let value: Double   // .nan 은 JSON 으로 표현할 수 없다
}

@Suite("경계 케이스")
struct EdgeCaseTests {
    // 보내는 쪽 실패를 `decodingFailed` 로 부르면 로그 보는 사람이 응답 파싱을 뒤진다.
    @Test("요청 본문 인코딩 실패는 encodingFailed 이고, 요청이 나가지 않는다")
    func encodingFailure() async throws {
        let (sut, stub) = makeSUT()

        let error = await capture {
            _ = try await sut.request(Endpoint<OkResponse>(
                path: "api/v1/rooms",
                method: .post,
                body: .json(BadBody(value: .nan))
            ))
        }

        guard case .encodingFailed = error else {
            Issue.record("encodingFailed 를 기대했는데 \(String(describing: error))")
            return
        }
        #expect(stub.recorded.isEmpty)
    }

    @Test("2xx 인데 본문이 비어 있으면 decodingFailed 로 드러난다")
    func emptySuccessBody() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.statusCode = 200
        stub.stub.body = Data()

        let error = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

        guard case .decodingFailed = error else {
            Issue.record("decodingFailed 를 기대했는데 \(String(describing: error))")
            return
        }
    }

    // 카페 와이파이·캡티브 포털이 200 에 HTML 을 끼워 넣는 상황.
    @Test("2xx 인데 JSON 이 아니면 크래시하지 않고 decodingFailed 로 나온다")
    func htmlSuccessBody() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.body = Data("<html>captive portal</html>".utf8)

        let error = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

        guard case .decodingFailed = error else {
            Issue.record("decodingFailed 를 기대했는데 \(String(describing: error))")
            return
        }
    }

    @Test("201·202 도 성공 경로다", arguments: [201, 202])
    func createdAndAccepted(_ status: Int) async throws {
        let (sut, stub) = makeSUT()
        stub.stub.statusCode = status
        stub.stub.body = Data(#"{"data":{"ok":true}}"#.utf8)

        let ok = try await sut.request(Endpoint<OkResponse>(path: "api/v1/rooms", method: .post))
        #expect(ok.ok)
    }

    // 429 는 스펙에 없어서 4xx 폴백으로 떨어진다. `.server` 가 아니라는 걸 못박는다.
    @Test("429 는 client 로 떨어진다 — server 가 아니다")
    func rateLimited() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.statusCode = 429
        stub.stub.body = Data(#"{"errorCode":"TOO_MANY","message":"잠시 후"}"#.utf8)

        let error = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

        #expect(error == .client(statusCode: 429, code: "TOO_MANY", message: "잠시 후"))
    }

    @Test("전송 오류는 갈래별로 번역된다", arguments: [
        (URLError.Code.timedOut, TransportFailure.timedOut),
        (.notConnectedToInternet, .notConnected),
        (.networkConnectionLost, .notConnected),
        (.cannotFindHost, .cannotFindHost),
        (.secureConnectionFailed, .unknown),
    ])
    func transportReasons(_ code: URLError.Code, _ expected: TransportFailure) async throws {
        let (sut, stub) = makeSUT()
        stub.stub.error = URLError(code)

        let error = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

        #expect(error == .transport(reason: expected))
    }

    // URLError 가 아닌 오류가 와도 AFError 가 새면 안 된다.
    @Test("URLError 가 아닌 전송 오류도 transport 로 갇힌다")
    func nonURLErrorTransport() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.error = NSError(domain: "custom", code: 42)

        let error = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

        #expect(error == .transport(reason: .unknown))
    }

    @Test("쿼리의 + 가 공백으로 뒤바뀌지 않게 인코딩된다")
    func plusInQuery() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.body = Data(roomsJSON.utf8)

        _ = try await sut.request(Endpoint<[RoomDTO]>(
            path: "api/v1/pins",
            queryItems: [URLQueryItem(name: "keyword", value: "C++ 스터디")]
        ))

        let url = try #require(stub.recorded.first?.url?.absoluteString)
        #expect(url.contains("C%2B%2B"))
    }

    @Test("body 가 있어도 호출부의 Content-Type 이 이긴다")
    func contentTypeOverride() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.body = Data(#"{"data":{"ok":true}}"#.utf8)

        _ = try await sut.request(Endpoint<OkResponse>(
            path: "api/v1/rooms",
            method: .post,
            headers: ["Content-Type": "application/x-ndjson"],
            body: .json(CreateRoomBody(name: "제주", color: "#FFF"))
        ))

        #expect(stub.recorded.first?.value(forHTTPHeaderField: "Content-Type") == "application/x-ndjson")
    }

    // 세션별 격리가 실제로 새지 않는지 — 미래에 누가 static 스텁을 되살리는 걸 막는다.
    @Test("두 클라이언트를 동시에 때려도 서로의 stub 을 보지 않는다")
    func sessionIsolation() async throws {
        let (sutA, stubA) = makeSUT()
        let (sutB, stubB) = makeSUT()
        stubA.stub.body = Data(#"{"data":[{"id":"A","name":"A방","createdAt":"2026-08-01T09:00:00Z"}]}"#.utf8)
        stubB.stub.body = Data(#"{"data":[{"id":"B","name":"B방","createdAt":"2026-08-01T09:00:00Z"}]}"#.utf8)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    let rooms = try? await sutA.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms"))
                    #expect(rooms?.first?.id == "A")
                }
                group.addTask {
                    let rooms = try? await sutB.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms"))
                    #expect(rooms?.first?.id == "B")
                }
            }
        }

        #expect(stubA.recorded.count == 10)
        #expect(stubB.recorded.count == 10)
    }
}
