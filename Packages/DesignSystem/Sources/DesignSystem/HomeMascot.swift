import SwiftUI

/// 홈 우상단에서 화면 밖으로 반쯤 걸쳐 있는 마스코트 아트 13종 (Figma `character/Home_Avatar`).
///
/// 몸통은 13종이 모두 같고 **소품만 다르다** — 셰프 모자·밀짚모자·귀마개·하트 선글라스 등.
/// 그래서 눈 구멍을 메우는 `homeMascotEyes` 오버레이 한 장을 13종이 함께 쓴다
/// (`FeatureHome.HomeMascotView` 참조).
///
/// > 케이스 이름은 Figma 배리언트 이름(팔레트 색 키)을 그대로 옮긴 것이다. **어떤 색이 어떤 계정에
/// > 저장되는지는 DesignSystem 이 알지 않는다** — 서버 계약이라 화면 레이어
/// > (`ProfileSetupUI.AvatarPalette`)가 잇는다(``MHCharacter`` 와 같은 이유).
public enum MHHomeMascot: String, CaseIterable, Sendable {
    /// 소품 없는 기본 마스코트 (Figma `Property 1=black`). 아바타 색을 아직 고르지 않은 계정 자리다.
    case plain = "homeMascot"
    case red = "homeMascotRed"
    case redOrange = "homeMascotRedOrange"
    case orange = "homeMascotOrange"
    case green = "homeMascotGreen"
    case purple = "homeMascotPurple"
    case lime = "homeMascotLime"
    case cyan = "homeMascotCyan"
    case pink = "homeMascotPink"
    case blue = "homeMascotBlue"
    case brown = "homeMascotBrown"
    case lightBlue = "homeMascotLightBlue"
    case violet = "homeMascotViolet"
}

public extension Image {
    /// 홈 마스코트 아트를 로드한다. 멀티컬러 원본이라 템플릿 렌더링이 아니다.
    init(_ mascot: MHHomeMascot) {
        self.init(mascot.rawValue, bundle: .module)
    }
}
