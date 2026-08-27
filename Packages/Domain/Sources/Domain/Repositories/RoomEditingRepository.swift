/// 방을 만들고 고치는 컬렉션 인터페이스.
///
/// `RoomRepository`(목록 조회)와 나눠 둔다 — 목록은 아직 Mock 구현을 쓰고 생성·수정만 실 API 라,
/// 한 프로토콜에 합치면 양쪽 구현체가 서로 쓰지 않는 메서드를 떠안는다.
/// 둘 다 실 API 가 되면 합칠지 다시 판단한다.
public protocol RoomEditingRepository: Sendable {
    func create(name: String, description: String?, color: RoomColor) async throws -> Room

    /// 부분 수정(PATCH)이지만 세 필드를 모두 보낸다 — 폼이 항상 전체 값을 들고 있어
    /// 일부만 보낼 이유가 없고, `nil` 이 "안 바꿈"인지 "지움"인지 모호해지는 것도 피한다.
    func update(roomId: String, name: String, description: String?, color: RoomColor) async throws -> Room
}
