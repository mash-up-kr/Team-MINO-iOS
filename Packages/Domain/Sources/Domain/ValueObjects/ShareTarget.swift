import Foundation

/// "다른 방에 공유" 후보 한 칸 — 방과, **그 방에 이 장소가 이미 있는지**.
///
/// `alreadySaved` 를 `Room` 에 넣지 않는다. 그건 방의 속성이 아니라 *특정 장소에 대한* 방의 상태,
/// 즉 관계적 사실이다. Entity 에 심으면 일반 조회로 받은 `Room` 과 장소 지정 조회로 받은 `Room` 이
/// 같은 타입인데 다른 의미를 갖는다.
public struct ShareTarget: Equatable, Sendable {
    public let room: Room
    /// 이미 저장돼 있으면 선택 대상이 아니다 — 화면은 체크된 상태로 비활성 표시한다.
    public let alreadySaved: Bool

    public init(room: Room, alreadySaved: Bool) {
        self.room = room
        self.alreadySaved = alreadySaved
    }
}
