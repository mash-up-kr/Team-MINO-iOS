import Domain
import Networking

extension Networking.Page {
    /// 경계(Data → Domain) 변환. `HTTPClient.requestPage` 가 돌려준 한 장을 Domain 값 타입으로 옮긴다.
    /// [Convention] Packages/Networking/Docs/AddingAPI.md — `Networking.Page` 를 Domain 경계 밖으로
    /// 내보내지 않는다. envelope(`{data, pagination}`) 해석은 Networking 이 이미 끝냈고, 여기서는
    /// 그 결과를 Domain 어휘로 옮기기만 한다.
    ///
    /// 다음 장 크기는 **응답의 `pagination.pageSize` 가 아니라 우리가 보낸 `request.pageSize`** 를 쓴다.
    /// 서버가 그 필드에 "이번 장에 실제 담긴 개수" 를 실어 보내면(요청 크기의 에코가 아니라), 그 값을
    /// 되먹인 다음 요청은 오프셋이 어긋나 이미 본 항목을 다시 가져온다. 요청값을 쓰면 둘 중 어느
    /// 쪽이든 안전하다 — Networking 은 서버가 준 값을 그대로 전달할 뿐이라 이 판단은 여기 몫이다.
    ///
    /// 항목 매핑이 실패를 던질 수 있게 `rethrows` 로 열어 둔다. `items.map` 이라 항목 하나가 던지면
    /// 그 순간 전체가 실패하고 이미 변환된 부분 결과도 버려진다. 알 수 없는 값을 흡수할지 던질지는
    /// 이 함수가 정하지 않는다 — `transform` 을 넘기는 호출부의 정책이다.
    func toDomain<T>(
        request: PageRequest,
        _ transform: (Element) throws -> T
    ) rethrows -> Domain.Page<T> {
        Domain.Page(
            items: try items.map(transform),
            page: pagination.page,
            pageSize: request.pageSize,
            hasNext: pagination.hasNext
        )
    }
}
