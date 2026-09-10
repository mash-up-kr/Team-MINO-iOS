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
    /// 이미 저장돼 있다면 **그 방 쪽 핀**. 같은 장소라도 방마다 핀이 따로라, 저장된 방으로
    /// 건너뛰려면(기획 014 ②) 방 id 만으로는 부족하다.
    ///
    /// `alreadySaved == false` 면 당연히 `nil` 이고, 참이어도 서버가 매칭 핀을 못 집으면 `nil` 이다.
    public let matchedPinID: PinID?

    public init(room: Room, alreadySaved: Bool, matchedPinID: PinID? = nil) {
        self.room = room
        self.alreadySaved = alreadySaved
        self.matchedPinID = matchedPinID
    }
}

public extension Sequence<ShareTarget> {
    /// 이 장소가 이미 담긴 방의 id — 시트가 체크·비활성으로 그릴 대상.
    /// 「다른 방에 공유」와 「게시물 저장」이 같은 조회를 쓰므로 파생도 한 자리에 둔다.
    var alreadySavedRoomIDs: Set<String> {
        Set(lazy.filter(\.alreadySaved).map(\.room.id))
    }
}
