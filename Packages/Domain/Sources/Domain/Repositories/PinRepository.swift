import Foundation

/// 도메인 관점에서 핀(Pin, 저장한 장소) 컬렉션에 접근하는 추상 인터페이스.
/// 구현체(Data 계층)가 API/DB/Cache/Mock 중 무엇을 쓰는지 Domain 은 알지 못한다.
/// 방은 식별자(RoomID)로만 참조한다 — aggregate 통째가 아니라 identity 로 경계를 넘는다.
public protocol PinRepository: Sendable {
    /// 방 id 목록과 조회 기준을 받아, 각 방의 핀을 목록 순서대로 이어붙인 평면 배열을 반환한다(홈 카드 덱).
    func pins(roomIDs: [RoomID], filter: PinFilter) async throws -> [Pin]
    /// 특정 방의 다음 페이지 핀을 반환한다("이 방 장소 더 보기"). page 는 0 부터 시작하는 페이지 커서.
    func pins(roomID: RoomID, page: Int, filter: PinFilter) async throws -> [Pin]
}
