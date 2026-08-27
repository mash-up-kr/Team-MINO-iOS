/// 방 대표 색. 식별자 없이 값 자체로 동등한 Value Object.
///
/// **rawValue 가 서버와 주고받는 문자열이다.** 서버는 hex 가 아니라 이 이름을 그대로 쓴다
/// (`POST /api/v1/rooms` 의 `color`). 다중 단어는 **snake_case** 다 — kebab(`red-orange`)은 서버가
/// `색상은 팔레트 키 중 하나여야 합니다` 로 거부한다(아바타 색에서 실측 확인).
///
/// > ⚠️ **`red_orange`·`light_blue` 는 아직 저장할 수 없다.** 서버가 `rooms.color` 에 `maxLength: 7`
/// > 을 걸어 두어 10자인 두 값이 길이에서 먼저 막힌다(400). 철자를 뭘로 바꿔도 통과하지 못하므로
/// > 서버 제한 완화가 필요하다. 나머지 11색은 정상 동작한다.
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
