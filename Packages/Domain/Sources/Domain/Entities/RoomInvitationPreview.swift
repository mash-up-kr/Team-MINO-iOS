import Foundation

/// 초대 코드로 미리 본 방. **합류하기 전에** 코드가 가리키는 곳을 확인하는 값이다.
///
/// `Room` 과 갈라 두는 이유는 서버가 주는 것이 다르기 때문이다 — 이 응답에는 `ownerId`·`createdAt`
/// 이 없어 `Room` 을 세울 수 없다. 합류 뒤 방 상세를 열 때 `FetchRoomUseCase` 로 다시 조회한다.
///
/// 이 조회는 **인증이 필요 없다**(서버 스펙) — 온보딩을 마치지 않은 사용자도 초대의 유효성을
/// 미리 확인할 수 있다. 초대 유무가 온보딩 경로를 바꾸므로(공동방 생성·친구초대 스킵) 그 판단
/// 전에 코드를 검증해야 한다.
public struct RoomInvitationPreview: Equatable, Sendable {
    /// 합류 API 가 path 로 요구하는 값. 코드에서 방을 푸는 유일한 수단이다.
    public let roomID: String
    public let roomType: RoomType
    public let roomName: String
    public let roomDescription: String?
    /// 서버가 팔레트에 없는 이름을 주면 `nil` — 그리는 쪽이 기본 썸네일로 폴백한다(`Room` 과 같은 규약).
    public let roomColor: RoomColor?
    public let pinCount: Int
    public let memberCount: Int
    /// 초대한 사람. 확인 화면을 두게 되면 여기를 쓴다.
    public let inviterNickname: String

    public init(
        roomID: String,
        roomType: RoomType,
        roomName: String,
        roomDescription: String?,
        roomColor: RoomColor?,
        pinCount: Int,
        memberCount: Int,
        inviterNickname: String
    ) {
        self.roomID = roomID
        self.roomType = roomType
        self.roomName = roomName
        self.roomDescription = roomDescription
        self.roomColor = roomColor
        self.pinCount = pinCount
        self.memberCount = memberCount
        self.inviterNickname = inviterNickname
    }
}
