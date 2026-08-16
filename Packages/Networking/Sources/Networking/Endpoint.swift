import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// 요청 본문. 업로드 계약이 정해지면 그 방식에 맞는 케이스를 추가한다.
public enum HTTPBody: Sendable {
    case json(any Encodable & Sendable)
}

/// 하나의 API 요청. **응답 타입을 제네릭에 담아** 호출부가 타입을 다시 적지 않게 한다.
///
/// 제네릭 파라미터는 서버 응답의 `data` **안쪽 알맹이**다.
/// envelope(`{"data": …}`)은 `HTTPClient` 구현체가 벗긴다.
///
///     Endpoint<[RoomDTO]>(path: "api/v1/rooms")   // ← {"data": [ … ]}
public struct Endpoint<Response: Decodable & Sendable>: Sendable {
    public let path: String
    public let method: HTTPMethod
    public let queryItems: [URLQueryItem]
    public let headers: [String: String]
    public let body: HTTPBody?
    /// 스펙상 인증 예외는 `POST /api/v1/users`, `GET /api/v1/invitations/{code}` 둘뿐이다.
    ///
    /// ⚠️ **아직 아무도 이 값을 읽지 않는다**(인증 미구현). 붙일 때 주의할 점:
    /// 세션 레벨 `RequestAdapter` 는 `URLRequest` 만 보므로 이 플래그를 알 수 없다.
    /// 세션 어댑터로 토큰을 주입하면 **회원가입 요청에도 토큰이 붙고, 401 갱신까지 돌아간다.**
    /// 요청별 인터셉터를 넘기거나 마커 헤더로 전달하는 경로가 필요하다.
    public let requiresAuth: Bool
    /// nil 이면 세션 전역 설정을 따른다.
    public let timeout: TimeInterval?

    public init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: HTTPBody? = nil,
        requiresAuth: Bool = true,
        timeout: TimeInterval? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
        self.requiresAuth = requiresAuth
        self.timeout = timeout
    }
}

public extension Endpoint {
    /// offset 기반 페이지네이션 쿼리(`page`·`pageSize`)를 붙인 요청을 만든다.
    ///
    /// 서버는 둘 다 생략하면 전체를 반환하므로, 전체 조회에는 쓰지 않는다.
    /// 반환 타입이 `PagedEndpoint` 라 `requestPage` 로만 보낼 수 있다 — `request` 로 보내
    /// `pagination` 을 잃는 실수가 컴파일 단계에서 막힌다.
    func paged<Element>(page: Int, pageSize: Int) -> PagedEndpoint<Element> where Response == [Element] {
        // 서버가 준 `pagination.pageSize` 를 그대로 다음 요청에 넘기는 건 무한스크롤의 표준
        // 구현이다. 여기서 precondition 을 걸면 **백엔드 값 하나로 릴리즈 앱이 죽는다.**
        // 스펙 범위(1...100)로 조용히 맞추고, 개발 중에만 어긋남을 알린다.
        assert(page >= 0 && (1...100).contains(pageSize), "page/pageSize 가 서버 스펙 범위를 벗어났다")
        let safePage = max(page, 0)
        let safePageSize = min(max(pageSize, 1), 100)

        // 이미 붙어 있던 page·pageSize 는 걷어낸다. 저장해 둔 endpoint 에 거듭 적용하면
        // `?page=0&page=1` 처럼 중복돼 서버 해석이 갈린다.
        let carried = queryItems.filter { $0.name != "page" && $0.name != "pageSize" }
        return PagedEndpoint(endpoint: Endpoint<[Element]>(
            path: path,
            method: method,
            queryItems: carried + [
                URLQueryItem(name: "page", value: String(safePage)),
                URLQueryItem(name: "pageSize", value: String(safePageSize)),
            ],
            headers: headers,
            body: body,
            requiresAuth: requiresAuth,
            timeout: timeout
        ))
    }
}
