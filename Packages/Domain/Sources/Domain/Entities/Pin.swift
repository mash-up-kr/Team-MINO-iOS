import Foundation

/// 방에 저장된 장소 한 건 — aggregate root.
///
/// 다른 aggregate(방)는 식별자로만 가리킨다(`roomID`). 반면 `Place` 는 이 aggregate 안의 Entity 라
/// 임베드한다 — 자세한 근거는 `Place` 주석.
///
/// 홈 카드 뱃지용 큐레이션 라벨은 들지 않는다 — 라벨은 홈 카드 응답에만 실리는 값이라 `PinCard` 가 든다.
///
/// 프레임워크에 의존하지 않는 순수 value type 이며 Codable 을 준수하지 않는다(API 스키마와 결합 방지).
public struct Pin: Equatable, Identifiable, Sendable {
    public let id: PinID
    public let roomID: String
    public let place: Place
    /// 게시물에서 가져온 사진. 없을 수 있다.
    public let images: [URL]
    /// 이 장소를 저장한 멤버("누가 추가한 곳" 표시용). 서버가 주지 않으면 nil.
    public let createdBy: MemberProfile?
    /// 이 장소에 달린 코멘트 수. 목록에 실려오는 집계값이라 코멘트 본문 없이도 "코멘트 N" 을 그릴 수 있다.
    public let commentCount: Int
    public let createdAt: Date

    public init(
        id: PinID,
        roomID: String,
        place: Place,
        images: [URL] = [],
        createdBy: MemberProfile? = nil,
        commentCount: Int = 0,
        createdAt: Date
    ) {
        self.id = id
        self.roomID = roomID
        self.place = place
        self.images = images
        self.createdBy = createdBy
        self.commentCount = commentCount
        self.createdAt = createdAt
    }
}
