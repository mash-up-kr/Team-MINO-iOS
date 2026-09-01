import DesignSystem
import Domain

/// 방 대표 색 → 홈 우상단 **방 캐릭터** 아트 (Figma `character/Home_Avatar`).
///
/// 홈 상단은 「현재 방의 뱃지와 방 캐릭터」이고, 방이 바뀌면 둘 다 교체된다(FR-021, Flow F).
/// 그래서 이 마스코트는 **보는 사람이 아니라 보고 있는 방**을 나타낸다 —
/// 예전 구현이 내 프로필 아바타 색을 쓰던 탓에 방을 옮겨도 캐릭터가 그대로였다.
///
/// ``ProfileSetupUI.AvatarPalette/homeMascot(of:)`` 와 나란한 자리지만 **받는 색이 다르다** —
/// 저쪽은 계정의 ``AvatarColor``(12색), 이쪽은 방의 ``RoomColor``(13색)다.
/// DesignSystem 이 "어떤 색이 어느 도메인 값인지" 를 모르게 두는 규약은 그대로 따른다
/// (``MHHomeMascot`` 주석 참조) — 그 이음은 화면 레이어인 여기서 한다.
enum HomeMascotPalette {

    /// 색을 모르는 방(`nil`)과 색을 고르지 않은 방(``RoomColor/gray``)은 **소품 없는 기본 마스코트**다.
    ///
    /// `gray` 는 피커에 칸이 없는 13번째 값이라 대응하는 소품 아트가 없다. 아무 색이나 골라
    /// 남의 소품을 씌우는 것보다, 시안이 그 자리에 둔 "아직 안 고름" 그림(``MHHomeMascot/plain``)을
    /// 그대로 쓰는 편이 맞다 — 개인방(`내 장소`)이 늘 이 자리다.
    static func mascot(of color: RoomColor?) -> MHHomeMascot {
        switch color {
        case .red: .red
        case .redOrange: .redOrange
        case .orange: .orange
        case .lime: .lime
        case .green: .green
        case .cyan: .cyan
        case .lightBlue: .lightBlue
        case .blue: .blue
        case .violet: .violet
        case .pink: .pink
        case .purple: .purple
        case .brown: .brown
        case .gray, nil: .plain
        }
    }
}
