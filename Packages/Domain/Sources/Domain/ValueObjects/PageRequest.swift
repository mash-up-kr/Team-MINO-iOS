/// 목록 API 에 보낼 한 장의 요청.
/// 기본 페이지 크기를 여기 두지 않는다 — 서버 사정이지 도메인 어휘가 아니라서 Data 가 안다.
public struct PageRequest: Equatable, Sendable {
    /// 0-based. `Page.page` 와 같은 기준.
    public let page: Int
    public let pageSize: Int

    /// 잘못된 크기가 네트워크로 나가기 전에 막는다. `PageRequest` 는 서버 응답이 아니라
    /// 우리 코드만 만드는 값이라, 여기서 깨지는 건 프로그래머 실수다.
    public init(page: Int, pageSize: Int) {
        precondition(pageSize > 0, "pageSize 는 1 이상이어야 한다 (받은 값: \(pageSize))")
        self.page = page
        self.pageSize = pageSize
    }

    /// 첫 장 요청.
    public static func first(pageSize: Int) -> PageRequest {
        PageRequest(page: 0, pageSize: pageSize)
    }
}
