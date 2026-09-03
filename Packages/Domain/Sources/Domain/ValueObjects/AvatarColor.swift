import Foundation

/// 프로필 아바타 색. 식별자 없이 값 자체로 동등한 Value Object.
///
/// **rawValue 가 서버와 주고받는 문자열이다** (`POST /api/v1/users` 의 `avatar.color`).
/// 다중 단어는 **snake_case** 다 — kebab(`red-orange`)을 보내면 서버가
/// `400 색상은 팔레트 키 중 하나여야 합니다` 로 거부한다(실측 확인).
/// 값은 Figma `Atomic` 팔레트 토큰명을 옮긴 것이라 임의로 줄이지 않는다 —
/// 디자인·에셋·서버가 한 어휘를 쓰게 하려는 것이다.
///
/// > 방 색(`RoomColor`)과 케이스가 같지만 타입을 나눠 둔다. 서버가 두 계약을 따로 정의하고
/// > 있어(방은 `maxLength 7`, 아바타는 `20`) 한쪽이 늘어도 다른 쪽이 따라가지 않는다.
public enum AvatarColor: String, Equatable, Sendable, CaseIterable {
    case red
    case redOrange = "red_orange"
    case orange
    case green
    case purple
    case lime
    case cyan
    case pink
    case blue
    case brown
    case lightBlue = "light_blue"
    case violet
    /// 아직 아바타를 고르지 않음. 그리드에 칸이 없고 소품 없는 기본 그림으로 그려진다
    /// (`ProfileSetupUI.AvatarPalette`). `RoomColor.gray` 와 같은 자리다.
    case gray
}
