import SwiftUI

/// 지도 마커 캐릭터 아트의 색 축 13종 (Figma `character/Pin`).
///
/// rawValue 는 에셋 이름의 **접미사**다 — ``MHMapPinState`` 의 접두사와 이어 붙여
/// `pinActiveRed` 처럼 완성된다. `plain` 만 Figma 배리언트 이름(`black`)을 따라 `"Black"` 이다.
///
/// > 어떤 색이 어떤 계정·방에 저장되는지는 DesignSystem 이 알지 않는다 — 서버 계약이라 화면
/// > 레이어(`ProfileSetupUI.AvatarPalette`)가 잇는다(``MHHomeMascot`` 와 같은 이유).
public enum MHMapPinColor: String, CaseIterable, Sendable {
    /// 색을 아직 고르지 않은 자리 (Figma `color=black`). 회색 실루엣이다.
    case plain = "Black"
    case red = "Red"
    case redOrange = "RedOrange"
    case orange = "Orange"
    case lime = "Lime"
    case green = "Green"
    case cyan = "Cyan"
    case lightBlue = "LightBlue"
    case blue = "Blue"
    case violet = "Violet"
    case purple = "Purple"
    case pink = "Pink"
    case brown = "Brown"
}

/// 지도 마커의 선택 상태. Figma `Pin` 프레임의 `mode` 축이다.
///
/// rawValue 는 에셋 이름의 **접두사**다.
public enum MHMapPinState: String, CaseIterable, Sendable {
    /// 탭해서 펼친 마커 (Figma `activate`). 얼굴·소품이 보이는 56×61 큰 핀.
    case selected = "pinActive"
    /// 기본 마커 (Figma `default`). 색 실루엣만 있는 42×48 작은 핀.
    case normal = "pinDefault"
}

public extension Image {
    /// 지도 마커 아트를 로드한다. 멀티컬러 원본이라 템플릿 렌더링이 아니다.
    ///
    /// 배리언트마다 폭이 조금씩 다르다(`cyan` 은 귀마개가 옆으로 삐져나와 58 폭이다).
    /// **높이를 기준으로 맞추고 가로는 중앙 정렬**해야 핀 끝이 흔들리지 않는다.
    init(mapPin color: MHMapPinColor, state: MHMapPinState = .normal) {
        self.init(state.rawValue + color.rawValue, bundle: .module)
    }
}
