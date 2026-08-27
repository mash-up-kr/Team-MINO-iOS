import Domain

extension PageRequest {
    /// 서버가 정의한 기본 페이지 크기. 리포지토리가 각자 20 을 적지 않도록 여기 한 곳에 둔다.
    ///
    /// 쿼리 파라미터(`page`·`pageSize`)로 옮기는 일은 여기서 하지 않는다 —
    /// `Endpoint.paged(page:pageSize:)` 가 범위 클램프·중복 제거까지 포함해 이미 담당한다.
    static let defaultPageSize = 20
}
