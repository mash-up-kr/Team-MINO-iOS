import Foundation

/// 서버 공통 성공 응답 래퍼. 모든 성공 응답이 `{"data": …}` 이고,
/// 목록 응답은 `data` 의 **형제**로 `pagination` 을 함께 내려준다.
///
/// Networking 내부에만 존재한다 — 호출부는 envelope 을 알지 못한다.
struct APIEnvelope<T: Decodable>: Decodable {
    let data: T
    let pagination: Pagination?
}

/// offset 기반 페이지네이션 메타.
public struct Pagination: Decodable, Sendable, Equatable {
    public let pageSize: Int
    /// 0부터 시작한다.
    public let page: Int
    public let hasNext: Bool

    public init(pageSize: Int, page: Int, hasNext: Bool) {
        self.pageSize = pageSize
        self.page = page
        self.hasNext = hasNext
    }
}

/// 페이지네이션된 목록 응답.
///
/// `Element` 에 `Decodable` 을 요구하지 않는다 — 요구하면 Repository 가 `Page<RoomDTO>` 를
/// `Page<Room>`(Entity)으로 옮길 때 **Entity 에 `Decodable` 을 붙여야 해서**
/// "Entity 는 Codable 을 준수하지 않는다"(clean-architecture.md)와 충돌한다.
public struct Page<Element: Sendable>: Sendable {
    public let items: [Element]
    public let pagination: Pagination

    public init(items: [Element], pagination: Pagination) {
        self.items = items
        self.pagination = pagination
    }

    /// DTO → Entity 매핑용. 페이지 정보를 유지한 채 알맹이만 바꾼다.
    public func map<T>(_ transform: (Element) throws -> T) rethrows -> Page<T> {
        Page<T>(items: try items.map(transform), pagination: pagination)
    }
}

extension Page: Equatable where Element: Equatable {}

/// 페이지네이션을 쓰는 요청. `paged(page:pageSize:)` 로만 만들어지고 `requestPage` 로만 보낸다.
///
/// `Endpoint` 와 타입을 가르는 이유: 같은 타입이면 목록 엔드포인트를 `request` 로 부를 수 있고,
/// 그러면 `pagination` 이 **조용히 버려져** 무한스크롤이 다음 페이지에서 멈춘다.
public struct PagedEndpoint<Element: Decodable & Sendable>: Sendable {
    /// 감싼 요청. Repository 테스트가 "어떤 엔드포인트를 어떤 쿼리로 불렀는지" 확인해야 하므로
    /// 읽기는 열어둔다. 생성은 `paged(page:pageSize:)` 로만 — 그래야 짝이 유지된다.
    public let endpoint: Endpoint<[Element]>

    init(endpoint: Endpoint<[Element]>) {
        self.endpoint = endpoint
    }
}

/// 반환할 데이터가 없는 성공 응답. 서버는 204 대신 `{"data": {"ok": true}}` 를 준다.
public struct OkResponse: Decodable, Sendable, Equatable {
    public let ok: Bool
}
