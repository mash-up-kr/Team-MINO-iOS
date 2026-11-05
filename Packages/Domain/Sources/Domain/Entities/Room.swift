import Foundation

/// 고유 식별자(id)로 구분되는 도메인 Entity — 저장된 "방".
/// 프레임워크에 의존하지 않는 순수 value type 이며 Codable 을 준수하지 않는다(API 스키마와 결합 방지).
public struct Room: Equatable, Identifiable, Sendable {
    public let id: String
    public let type: RoomType
    public let name: String
    public let description: String?
    /// 방 대표 색. 서버가 팔레트에 없는 이름을 주면 `nil` — 그리는 쪽이 기본 썸네일로 폴백한다.
    public let color: RoomColor?
    public let ownerId: String
    public let createdAt: Date
    /// 저장된 장소 수("장소 N개").
    public let pinCount: Int
    /// 방 카드 썸네일에 콜라주로 깔 **최근 장소 사진 최대 4장**(최신순). 003-2 ④.
    ///
    /// 저장된 장소가 없으면 비어 있다 — 003-2 ③ 의 "장소 0개면 생성 시 고른 컬러칩+캐릭터 조합
    /// 유지" 가 이 빈 배열로 표현된다.
    public let placeThumbnails: [URL]
    public let memberCount: Int
    public let users: [RoomMember]

    /// 개인방 표기 이름 — 서버가 주는 `name` 과 무관하게 개인방은 어느 화면에서든 이 문구로 부른다.
    ///
    /// 화면 문구지만 Domain 에 두는 이유는 **쓰는 쪽이 한 패키지가 아니기 때문**이다. 홈(`FeatureHome`)과
    /// 공유 익스텐션이 각자 이 이름을 붙이는데, 익스텐션은 `Feature*` 를 링크할 수 없어(공유 UI 레이어의
    /// 금지 의존) 홈의 상수를 함께 쓰지 못한다. 둘 다 볼 수 있는 가장 안쪽 자리가 여기다.
    public static let personalDisplayName = "내 장소"

    public init(
        id: String,
        type: RoomType,
        name: String,
        description: String?,
        color: RoomColor?,
        ownerId: String,
        createdAt: Date,
        pinCount: Int,
        memberCount: Int,
        users: [RoomMember],
        placeThumbnails: [URL] = []
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.description = description
        self.color = color
        self.ownerId = ownerId
        self.createdAt = createdAt
        self.pinCount = pinCount
        self.memberCount = memberCount
        self.users = users
        self.placeThumbnails = placeThumbnails
    }
}

/// 방과 현재 사용자 신원만으로 정해지는 판정. 화면 상태를 보지 않으므로 Domain 이 든다 —
/// `PinComment.isWritten(by:)` 와 같은 모양으로, 신원을 모르면(nil) "아니다" 쪽으로 떨어진다.
extension Room {
    /// 이 방의 주인인가 — 닉네임이 아니라 **식별자**로만 판정한다.
    ///
    /// `viewer` 가 nil(내 신원을 아직·끝내 못 가져옴)이면 항상 false — 모르는 쪽을 "방장 아님" 으로
    /// 두어야 남의 방에 편집 항목이 붙는 사고가 나지 않는다.
    public func isOwned(by viewer: MemberID?) -> Bool {
        viewer?.value == ownerId
    }

    /// 공동방인가. 초대와 헤더 더보기(편집·나가기)는 공동방에만 있다 — 개인방은 "혼자만의 공간" 이라
    /// 초대 링크가 나가는 순간 방 종류의 정의가 깨진다(PRD 「개인방」 · [SYS-006]).
    public var isShared: Bool {
        type == .shared
    }

    /// `viewer` 가 나가면 방이 사라지는가 — 방장이자 마지막 멤버인 경우다.
    ///
    /// 최종 판단은 서버가 하고("방장+마지막 멤버면 방 삭제"), 여기서는 가진 값으로 미리 알려
    /// 나가기 확인 문구를 가른다.
    public func deletesWhenLeft(by viewer: MemberID?) -> Bool {
        isOwned(by: viewer) && memberCount <= 1
    }

    /// 방장 위임 후보 — 멤버 중 방장 본인을 뺀 나머지.
    public var ownerTransferCandidates: [RoomMember] {
        users.filter { $0.userId != ownerId }
    }
}
