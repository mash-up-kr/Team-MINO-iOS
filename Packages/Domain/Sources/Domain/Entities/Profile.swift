import Foundation

/// 사용자 자신의 프로필. 서버의 `GET /api/v1/users/me` 가 돌려주는 것과 같은 대상이다.
///
/// 아바타는 **색으로 식별한다** — 서버가 캐릭터 아트를 모르고 색 이름만 주고받기 때문이다
/// (`avatar.color`). 색 → 캐릭터 그림 매핑은 화면 레이어의 몫이다.
/// 서버가 아직 아바타를 안 준 계정이 있어 옵셔널이다.
public struct Profile: Equatable, Identifiable, Sendable {
    public let id: String
    public let nickname: String
    public let avatarColor: AvatarColor?
    public let createdAt: Date?

    public init(id: String, nickname: String, avatarColor: AvatarColor?, createdAt: Date?) {
        self.id = id
        self.nickname = nickname
        self.avatarColor = avatarColor
        self.createdAt = createdAt
    }
}
