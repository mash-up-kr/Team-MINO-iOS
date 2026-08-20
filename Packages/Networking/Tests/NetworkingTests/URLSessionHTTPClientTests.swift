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

    @Test("Endpoint.timeout 이 세션 전역 설정을 덮어쓴다")
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
}
