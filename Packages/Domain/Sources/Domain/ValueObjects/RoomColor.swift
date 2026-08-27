/// 방 대표 색 12가지. 식별자 없이 값 자체로 동등한 Value Object.
///
/// **rawValue 가 서버와 주고받는 문자열이다.** 서버는 hex 가 아니라 이 이름을 그대로 쓴다
/// (`POST /api/v1/rooms` 의 `color`). 표기가 바뀌면 여기만 고치면 된다.
///
/// > 색을 화면에 어떻게 그릴지는 Domain 이 모른다 — 피커 인덱스·썸네일 매핑은
/// > `RoomCreationUI` 의 `RoomColorPalette` 가 단독으로 든다.
public enum RoomColor: String, Equatable, Sendable, CaseIterable {
    case red, redOrange, orange, lime, green, cyan
    case lightBlue, blue, violet, pink, purple, brown
}
