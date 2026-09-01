import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 알림 목록 조회의 계약을 고정한다 — 어떤 경로·쿼리로 나가고, 응답이 어떤 페이지가 되며,
/// 인프라 오류가 어떤 도메인 어휘가 되는지.
///
/// **이 저장소에서 `requestPage` 를 실제로 쓰는 첫 경로다**(다른 Data 테스트의 스텁은 전부
/// `requestPage` 를 막아 뒀다). 그래서 스텁이 페이지 응답을 진짜로 조립한다.
@Suite("NotificationRepositoryImpl")
struct NotificationRepositoryImplTests {
    private static func item(_ id: String, type: String = "PIN_DUPLICATED") -> String {
        """
        { "id": "\(id)", "type": "\(type)", "typeLabel": "이미 저장해둔 곳이에요",
          "targetName": "패스트리 순간", "createdAt": "2026-09-01T12:00:00.000Z",
          "payload": { "placeId": "pin-\(id)" } }
        """
    }

    @Test("GET api/v1/notifications 로 나가고 페이지 파라미터가 실린다")
    func notifications_pathAndQuery() async throws {
        let client = StubPagedHTTPClient(json: "[\(Self.item("n1"))]", hasNext: false)
        let sut = NotificationRepositoryImpl(client: client)

        _ = try await sut.notifications()

        #expect(await client.lastPath == "api/v1/notifications")
        #expect(await client.query("page") == "0")
        #expect(await client.query("pageSize") == "20")
    }

    @Test("응답 항목이 알림으로 매핑된다")
    func notifications_mapsResponse() async throws {
        let client = StubPagedHTTPClient(
            json: "[\(Self.item("n1")),\(Self.item("n2", type: "SAVE_FAILED"))]",
            hasNext: false
        )
        let sut = NotificationRepositoryImpl(client: client)

        let page = try await sut.notifications()

        #expect(page.items.count == 2)
        #expect(page.items[0].title == "이미 저장해둔 곳이에요")
        #expect(page.items[0].destination == .place(pinID: PinID("pin-n1")))
        #expect(page.items[1].destination == .saveError)
    }

    // 무한스크롤이 실제로 다음 장을 부르는지 — `hasNext` 가 `Page.next` 로 이어지지 않으면
    // 목록이 첫 장에서 조용히 멈춘다.
    @Test("hasNext 가 다음 요청으로 이어지고 그 요청은 page=1 로 나간다")
    func notifications_nextRequestAdvancesPage() async throws {
        let client = StubPagedHTTPClient(json: "[\(Self.item("n1"))]", hasNext: true)
        let sut = NotificationRepositoryImpl(client: client)

        let first = try await sut.notifications()
        let next = try #require(first.next)
        _ = try await sut.notifications(next)

        #expect(next.page == 1)
        #expect(await client.query("page") == "1")
    }

    @Test("모르는 유형이 섞여도 페이지 전체가 살아남는다")
    func notifications_absorbsUnknownType() async throws {
        let client = StubPagedHTTPClient(
            json: "[\(Self.item("n1")),\(Self.item("n2", type: "REALLY_NEW_KIND"))]",
            hasNext: false
        )
        let sut = NotificationRepositoryImpl(client: client)

        let page = try await sut.notifications()

        #expect(page.items.count == 2)
        #expect(page.items[1].type == .unknown(raw: "REALLY_NEW_KIND"))
    }

    @Test("401 은 재인증이 필요한 unauthorized 로 번역된다")
    func unauthorizedIsTranslated() async {
        let client = StubPagedHTTPClient(error: NetworkError.unauthorized(code: "TOKEN_EXPIRED", message: "만료"))
        let sut = NotificationRepositoryImpl(client: client)

        await #expect(throws: DomainError.unauthorized) { try await sut.notifications() }
    }

    @Test("번역되지 않은 상태코드는 조회 실패로 떨어진다 — 오류를 흘리지 않는다")
    func untranslatedStatusFallsBack() async {
        let client = StubPagedHTTPClient(error: NetworkError.server(statusCode: 500))
        let sut = NotificationRepositoryImpl(client: client)

        await #expect(throws: DomainError.notificationsFetchFailed) { try await sut.notifications() }
    }

    // 서버가 pagination 을 빠뜨리면 requestPage 가 계약 위반으로 던진다. statusCode 가 없어
    // default 로 떨어지는데, 그 경로가 실제로 도메인 오류가 되는지 고정한다.
    @Test("페이지 메타가 빠진 응답은 조회 실패로 수렴한다")
    func missingPaginationFallsBack() async {
        let client = StubPagedHTTPClient(error: NetworkError.decodingFailed(description: "페이지 응답에 pagination 이 없음"))
        let sut = NotificationRepositoryImpl(client: client)

        await #expect(throws: DomainError.notificationsFetchFailed) { try await sut.notifications() }
    }

    @Test("취소는 CancellationError 로 되돌아온다")
    func cancellationStaysCancellation() async {
        let client = StubPagedHTTPClient(error: NetworkError.cancelled)
        let sut = NotificationRepositoryImpl(client: client)

        await #expect(throws: CancellationError.self) { try await sut.notifications() }
    }
}

/// 페이지 응답을 돌려주는 `HTTPClient` 스텁. **JSON 을 실제로 디코드**해 돌려준다 —
/// 타입드 DTO 를 바로 주면 디코딩 계약이 검증되지 않는다.
private actor StubPagedHTTPClient: HTTPClient {
    private let json: String?
    private let hasNext: Bool
    private let error: Error?
    private(set) var lastPath: String?
    private(set) var lastQuery: [URLQueryItem] = []

    init(json: String? = nil, hasNext: Bool = false, error: Error? = nil) {
        self.json = json
        self.hasNext = hasNext
        self.error = error
    }

    func query(_ name: String) -> String? {
        lastQuery.first { $0.name == name }?.value
    }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        throw NetworkError.cancelled   // 알림은 단건 조회를 쓰지 않는다
    }

    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Networking.Page<Element> {
        lastPath = endpoint.endpoint.path
        lastQuery = endpoint.endpoint.queryItems

        if let error { throw error }
        guard let json else { throw NetworkError.cancelled }
        let items = try APIDecoder.make().decode([Element].self, from: Data(json.utf8))
        let page = Int(query("page") ?? "0") ?? 0
        let pageSize = Int(query("pageSize") ?? "20") ?? 20
        return Networking.Page(
            items: items,
            pagination: Pagination(pageSize: pageSize, page: page, hasNext: hasNext)
        )
    }
}
