/// 방 대표 색. 식별자 없이 값 자체로 동등한 Value Object.
///
/// **rawValue 가 서버와 주고받는 문자열이다.** 서버는 hex 가 아니라 이 이름을 그대로 쓴다
/// (`POST /api/v1/rooms` 의 `color`). 다중 단어는 **snake_case** 다 — kebab(`red-orange`)은 서버가
/// `색상은 팔레트 키 중 하나여야 합니다` 로 거부한다(아바타 색에서 실측 확인).
///
/// 13색 전부가 서버 `enum` 에 그대로 있다 — 값이 하나라도 어긋나면 400 이므로 테스트로 고정한다
/// (`RoomColorPaletteTests`).
///
/// 값은 Figma `Atomic` 팔레트 토큰명을 옮긴 것이라
/// 임의로 줄이지 않는다 — 디자인·에셋(`roomThumbnail_*`)·서버가 한 어휘를 쓰게 하려는 것이다.
///
/// > 색을 고르지 않은 방은 ``gray`` 로 저장된다. 피커에 칸이 없는 13번째 값이라
/// > `RoomColorPalette.entries` 에 들어가지 않고, 썸네일도 없다(기본 my-room 으로 그린다).
public enum RoomColor: String, Equatable, Sendable, CaseIterable {
    case red
    case redOrange = "red_orange"
    case orange
    case lime
    case green
    case cyan
    case lightBlue = "light_blue"
    case blue
    case violet
    case pink
    case purple
    case brown
    /// 색 미선택. 서버가 `color` 를 필수로 요구해 "안 고름"도 값으로 표현한다.
    case gray
}
