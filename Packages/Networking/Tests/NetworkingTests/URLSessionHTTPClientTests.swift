import Alamofire
import Foundation
import Testing
@testable import Networking

@Suite("HTTPClient")
struct URLSessionHTTPClientTests {
    // MARK: - 디코딩 · envelope

    @Test("envelope 을 벗겨 data 안쪽만 돌려준다")
    func unwrapsEnvelope() async throws {
    let (sut, stub) = makeSUT()
    stub.stub.body = Data(roomsJSON.utf8)

    let rooms = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms"))

    #expect(rooms.count == 1)
    #expect(rooms[0].name == "우리 동네 맛집")
    }

    @Test("데이터 없는 성공은 200 + {data:{ok:true}} 로 온다")
    func okResponse() async throws {
    let (sut, stub) = makeSUT()
    stub.stub.body = Data(#"{"data":{"ok":true}}"#.utf8)

    let ok = try await sut.request(Endpoint<OkResponse>(path: "api/v1/pins/p1/accesses", method: .post))

    #expect(ok.ok)
    }

    @Test("requestPage 는 data 형제인 pagination 을 함께 돌려준다")
    func pagination() async throws {
    let (sut, stub) = makeSUT()
    stub.stub.body = Data(roomsJSON.utf8)

    let page = try await sut.requestPage(Endpoint<[RoomDTO]>(path: "api/v1/pins").paged(page: 0, pageSize: 20))

    #expect(page.items.count == 1)
    #expect(page.pagination == Pagination(pageSize: 20, page: 0, hasNext: true))
    }

    // 전체 조회는 page·pageSize 를 안 보내는 요청이라 `request` 로 받는다.
    // `requestPage` 로는 아예 부를 수 없다(PagedEndpoint 가 아니라서) — 타입이 짝을 강제한다.
    // 코드가 "nil 로 삼키면 hasNext 판단이 조용히 틀어진다"며 막아둔 분기다.
    // 누가 기본값으로 "친절하게" 바꾸면 무한스크롤이 첫 페이지에서 멈추는데, 이 테스트가 없으면 통과한다.
    @Test("페이지 요청인데 서버가 pagination 을 빠뜨리면 계약 위반으로 드러낸다")
    func pagedResponseWithoutPagination() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.body = Data(#"{"data":[]}"#.utf8)

        let error = await capture {
            _ = try await sut.requestPage(Endpoint<[RoomDTO]>(path: "api/v1/pins").paged(page: 0, pageSize: 20))
        }

        guard case .decodingFailed = error else {
            Issue.record("decodingFailed 를 기대했는데 \(String(describing: error))")
            return
        }
    }

    // pagination 키는 왔는데 필드가 빠진 경우. `pagination` 이 옵셔널이라 "없으면 nil" 로
    // 뭉개는 구현으로 바뀌면 hasNext 가 조용히 false 가 되어 무한스크롤이 멈춘다.
    @Test("pagination 필드가 결손이면 계약 위반으로 드러낸다")
    func pagedResponseWithPartialPagination() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.body = Data(#"{"data":[],"pagination":{"pageSize":20,"page":0}}"#.utf8)   // hasNext 없음

        let error = await capture {
            _ = try await sut.requestPage(Endpoint<[RoomDTO]>(path: "api/v1/pins").paged(page: 0, pageSize: 20))
        }

        guard case .decodingFailed = error else {
            Issue.record("decodingFailed 를 기대했는데 \(String(describing: error))")
            return
        }
    }

    // requestPage 는 send 결과에 pagination 검사를 덧붙이는 별도 경로다. 오류 번역이
    // request 쪽에만 걸려 있어도 위 테스트들은 전부 통과하므로 여기서 따로 못박는다.
    @Test("페이지 요청의 4xx 도 request 와 똑같이 번역된다")
    func pagedResponseClientError() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.statusCode = 403
        stub.stub.body = Data(#"{"errorCode":"NOT_A_MEMBER","message":"멤버가 아닙니다"}"#.utf8)

        let error = await capture {
            _ = try await sut.requestPage(Endpoint<[RoomDTO]>(path: "api/v1/pins").paged(page: 0, pageSize: 20))
        }

        #expect(error == .forbidden(code: "NOT_A_MEMBER", message: "멤버가 아닙니다"))
    }

    @Test("페이지 요청의 전송 실패도 transport 로 번역된다")
    func pagedResponseTransportError() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.error = URLError(.timedOut)

        let error = await capture {
            _ = try await sut.requestPage(Endpoint<[RoomDTO]>(path: "api/v1/pins").paged(page: 0, pageSize: 20))
        }

        #expect(error == .transport(reason: .timedOut))
    }

    @Test("전체 조회는 배열을 그대로 돌려준다")
    func fullListWithoutPagination() async throws {
    let (sut, stub) = makeSUT()
    stub.stub.body = Data(roomsJSON.utf8)

    let rooms = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/pins"))

    #expect(rooms.count == 1)
    }

    @Test("스키마가 어긋나면 decodingFailed 를 던진다")
    func decodingFailure() async throws {
    let (sut, stub) = makeSUT()
    stub.stub.body = Data(#"{"data":[{"id":123}]}"#.utf8)

    await #expect(throws: NetworkError.self) {
        try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms"))
    }
    }

    // MARK: - 요청 조립

    @Test("baseURL·경로·쿼리를 조립한다")
    func buildsURL() async throws {
    let (sut, stub) = makeSUT()
    stub.stub.body = Data(roomsJSON.utf8)

    _ = try await sut.requestPage(
        Endpoint<[RoomDTO]>(path: "api/v1/pins", queryItems: [URLQueryItem(name: "roomId", value: "r1")])
            .paged(page: 1, pageSize: 20)
    )

    let url = try #require(stub.recorded.first?.url)
    #expect(url.absoluteString == "https://stub.invalid/api/v1/pins?roomId=r1&page=1&pageSize=20")
    }

    @Test("본문이 있으면 JSON 으로 인코딩하고 Content-Type 을 붙인다")
    func encodesBody() async throws {
    let (sut, stub) = makeSUT()
    stub.stub.body = Data(#"{"data":{"ok":true}}"#.utf8)

    _ = try await sut.request(Endpoint<OkResponse>(
        path: "api/v1/rooms",
        method: .post,
        body: .json(CreateRoomBody(name: "제주 여행", color: "#FFC06E"))
    ))

    let request = try #require(stub.recorded.first)
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    let body = try #require(request.httpBody)
    #expect(String(decoding: body, as: UTF8.self).contains("제주 여행"))
    }

    @Test("본문이 없으면 Content-Type 을 붙이지 않는다")
    func noContentTypeWithoutBody() async throws {
    let (sut, stub) = makeSUT()
    stub.stub.body = Data(#"{"data":[]}"#.utf8)

    _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms"))

    let request = try #require(stub.recorded.first)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
    #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test("호출부가 넘긴 헤더가 기본값을 덮어쓴다")
    func headerOverride() async throws {
    let (sut, stub) = makeSUT()
    stub.stub.body = Data(#"{"data":[]}"#.utf8)

    _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms", headers: ["Accept": "text/plain"]))

    #expect(stub.recorded.first?.value(forHTTPHeaderField: "Accept") == "text/plain")
    }

    // 실제 만료 시각까지 재지는 않는다 — 시간 기반 테스트라 비용이 크고 CI 부하에서 흔들린다.
// URLSession 의 우선순위는 실측으로 확인했다(세션 0.3s + Endpoint 1.5s → 1.503s 에 만료,
// 세션 3.0s + Endpoint 0.4s → 0.405s 에 만료 — 개별 값이 늘리든 줄이든 항상 이긴다).
@Test("Endpoint.timeout 이 URLRequest 에 실린다")
    func timeoutOverride() async throws {
    let (sut, stub) = makeSUT()
    stub.stub.body = Data(#"{"data":[]}"#.utf8)

    _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms", timeout: 30))

    #expect(stub.recorded.first?.timeoutInterval == 30)
    }

    // MARK: - 오류

    @Test("4xx 는 errorCode·message 를 보존한다", arguments: [
    (400, "BAD_REQUEST"), (403, "FORBIDDEN"), (404, "NOT_FOUND"), (409, "CONFLICT"),
    ])
    func clientErrors(_ statusCode: Int, _ code: String) async throws {
    let (sut, stub) = makeSUT()
    stub.stub.statusCode = statusCode
    stub.stub.body = Data(#"{"errorCode":"\#(code)","message":"설명"}"#.utf8)

    let error = await capture { try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

    switch (statusCode, error) {
    case (400, .badRequest(let c, let m)), (403, .forbidden(let c, let m)),
         (404, .notFound(let c, let m)), (409, .conflict(let c, let m)):
        #expect(c == code)
        #expect(m == "설명")
    default:
        Issue.record("예상과 다른 오류: \(String(describing: error))")
    }
    }

    @Test("에러 본문이 약속 포맷이 아니면 상태코드를 보존한 채 드러낸다")
    func brokenErrorContract() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.statusCode = 403
        stub.stub.body = Data("<html>Forbidden</html>".utf8)

        let error = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

        // 상태코드가 문자열이 아니라 필드로 남아야 Data 계층이 403 을 알아본다.
        guard case .unexpectedErrorFormat(let statusCode, let preview) = error else {
            Issue.record("unexpectedErrorFormat 를 기대했는데 \(String(describing: error))")
            return
        }
        #expect(statusCode == 403)
        #expect(preview.contains("Forbidden"))
    }

    @Test("본문이 있는데 계약이 아닌 401 은 조용히 넘기지 않는다")
    func unauthorizedWithBrokenBody() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.statusCode = 401
        stub.stub.body = Data("<html>Gateway login</html>".utf8)

        let error = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

        // 케이스는 unauthorized 로 유지하되(재인증 흐름 보존), 로그로 계약 위반을 드러낸다.
        #expect(error == .unauthorized(code: nil, message: nil))
    }

    // 계약 위반이지만 케이스는 유지한다 — unexpectedErrorFormat 으로 보내면
// 다른 4xx 와 뭉뚱그려져 화면이 재인증을 안 한다.
@Test("본문 없는 401 도 unauthorized 로 받는다 — 재인증 흐름을 살린다")
    func unauthorizedWithoutBody() async throws {
    let (sut, stub) = makeSUT()
    stub.stub.statusCode = 401
    stub.stub.body = Data()

    let error = await capture { try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

    #expect(error == .unauthorized(code: nil, message: nil))
    }

    @Test("5xx 는 상태코드만 담는다")
    func serverError() async throws {
    let (sut, stub) = makeSUT()
    stub.stub.statusCode = 503
    stub.stub.body = Data()

    let error = await capture { try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

    #expect(error == .server(statusCode: 503))
    }

    @Test("전송 실패는 transport 로 번역한다 — AFError 가 새지 않는다")
    func transportError() async throws {
    let (sut, stub) = makeSUT()
    stub.stub.error = URLError(.notConnectedToInternet)

    let error = await capture { try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

    #expect(error == .transport(reason: .notConnected))
    }

    // 게이트웨이가 끼워 넣는 HTML 오류 페이지는 수십 KB 다. preview 에 상한이 없으면
    // 그게 통째로 오류 값에 실려 로그·크래시 리포트까지 따라간다.
    @Test("계약을 벗어난 본문이 길어도 preview 는 200자에서 끊는다")
    func truncatesUnexpectedFormatPreview() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.statusCode = 400
        stub.stub.body = Data(String(repeating: "A", count: 5_000).utf8)

        let error = await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

        guard case .unexpectedErrorFormat(let statusCode, let preview) = error else {
            Issue.record("unexpectedErrorFormat 를 기대했는데 \(String(describing: error))")
            return
        }
        #expect(statusCode == 400)
        #expect(preview.count == 200)
    }
}
