import Foundation

/// 사용자 자신의 프로필. 서버의 `GET /api/v1/users/me` 가 돌려주는 것과 같은 대상이다.
///
/// `avatarIndex` 는 캐릭터 목록에서의 자리(0 부터)다 — 목록 API 가 따로 없어 클라이언트가 아는
/// 고정 순서를 서버와 공유한다(DesignSystem `MHCharacter` 선언 순서). 서버가 아직 아바타를
/// 안 준 계정이 있어 옵셔널이다.
public struct Profile: Equatable, Identifiable, Sendable {
    public let id: String
    public let nickname: String
    public let avatarIndex: Int?
    public let createdAt: Date?

    public init(id: String, nickname: String, avatarIndex: Int?, createdAt: Date?) {
        self.id = id
        self.nickname = nickname
        self.avatarIndex = avatarIndex
        self.createdAt = createdAt
    }
}
