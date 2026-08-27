import Foundation

/// 프로필 아바타 색. 식별자 없이 값 자체로 동등한 Value Object.
///
/// **rawValue 가 서버와 주고받는 문자열이다** (`POST /api/v1/users` 의 `avatar.color`).
/// 값은 Figma `Atomic` 팔레트 토큰명을 kebab-case 로 옮긴 것이라 임의로 줄이지 않는다 —
/// 디자인·에셋·서버가 한 어휘를 쓰게 하려는 것이다.
///
/// > 방 색(`RoomColor`)과 케이스가 같지만 타입을 나눠 둔다. 서버가 두 계약을 따로 정의하고
/// > 있어(방은 `maxLength 7`, 아바타는 `20`) 한쪽이 늘어도 다른 쪽이 따라가지 않으며,
/// > 아바타에는 "안 고름"(`gray`)이 없다 — 무선택도 첫 캐릭터로 저장한다.
public enum AvatarColor: String, Equatable, Sendable, CaseIterable {
    case red
    case redOrange = "red-orange"
    case orange
    case green
    case purple
    case lime
    case cyan
    case pink
    case blue
    case brown
    case lightBlue = "light-blue"
    case violet
}
