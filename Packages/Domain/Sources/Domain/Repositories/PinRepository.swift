import Foundation

/// 도메인 관점에서 핀(Pin, 저장한 장소) 컬렉션에 접근하는 추상 인터페이스.
/// 구현체(Data 계층)가 API/DB/Cache/Mock 중 무엇을 쓰는지 Domain 은 알지 못한다.
///
/// 읽기가 두 갈래인 것은 **서버가 두 가지 다른 답을 주기 때문**이다 — 홈은 서버가 골라 준
/// 한 줌의 카드(라벨 4종으로 채운 덱)를 받고, 목록·지도는 조회 기준에 맞는 장소 목록을 받는다.
/// 하나로 합치면 호출부가 "이번엔 목록인가 골라 준 덱인가" 를 시그니처로 알 수 없다.
public protocol PinRepository: Sendable {
    /// 홈 카드 덱 — 서버가 조회 기준으로 후보를 좁힌 뒤 라벨 4종으로 골라 준 한 덱.
    /// 정원이 미달인 라벨은 채우지 않으므로 요청한 만큼 오지 않을 수 있다.
    ///
    /// - Parameter origin: 내 위치. `filter == .nearby` 일 때만 쓰이며, 그때는 **필수**다
    ///   (없이 보내면 서버가 거절한다). 다른 기준에서는 무시된다.
    func cards(roomID: String, filter: PinFilter, origin: Coordinate?) async throws -> [Pin]

    /// 저장된 장소 목록. **정렬·카테고리 필터를 서버가 한다** — 앱은 기준을 지정해 요청하고
    /// 받은 순서를 그대로 그린다(PRD 「목록 정렬 기준」: "재정렬하지도 걸러내지도 않는다").
    ///
    /// - Parameters:
    ///   - roomID: 방 하나로 좁힐 때 그 방. **`nil` 이면 내가 속한 모든 방**을 받는다 —
    ///     방 리스트 탭 지도가 "내 모든 방의 장소 마커" 를 그릴 때 쓴다(PRD [SYS-004]).
    ///   - origin: 내 위치. `sort == .distance` 일 때만 쓰이며 그때는 **필수**다
    ///     (없이 보내면 서버가 거절한다). 다른 기준에서는 무시된다 — ``cards(roomID:filter:origin:)``
    ///     와 같은 규약이다.
    func pins(
        roomID: String?,
        sort: PinSort,
        category: PlaceCategoryFilter,
        origin: Coordinate?
    ) async throws -> [Pin]
}
