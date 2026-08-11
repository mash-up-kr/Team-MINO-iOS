import SwiftUI

//
// 원칙적으로 화면·컴포넌트는 시맨틱 토큰(`Color.mh*` in SemanticColors)만 쓴다.
// 다만 Figma 가 **대응하는 시맨틱 토큰 없이 애터믹 팔레트 색을 직접 쓴 경우**
// (예: 사용자가 고르는 방 색상, 특정 일러스트 배경), hex/rgb 를 코드에 박지 않고
// 여기에 **Figma 이름 그대로** 에셋으로 등록해 토큰으로 쓴다.
// (`AtomicColor.xcassets` 에 colorset 추가 → 아래에 접근자 추가)
//
// 애터믹은 팔레트 원시값이라 라이트/다크 구분 없이 단일값이다.

fileprivate extension Color {
    init(atomic name: String) { self.init(name, bundle: .module) }
}

public extension ShapeStyle where Self == Color {
    /// Figma atomic `Red/60` (#FF6363).
    static var mhRed60: Color { Color(atomic: "Red/60") }
    /// Figma atomic `Red/30` (#B00C0C).
    static var mhRed30: Color { Color(atomic: "Red/30") }

    /// Figma atomic `Red Orange/70` (#FF9B61).
    static var mhRedOrange70: Color { Color(atomic: "Red Orange/70") }
    /// Figma atomic `Red Orange/40` (#C94A00).
    static var mhRedOrange40: Color { Color(atomic: "Red Orange/40") }

    /// Figma atomic `Orange/70` (#FFC06E).
    static var mhOrange70: Color { Color(atomic: "Orange/70") }
    /// Figma atomic `Orange/40` (#D47800).
    static var mhOrange40: Color { Color(atomic: "Orange/40") }

    /// Figma atomic `Lime/80` (#AEF779).
    static var mhLime80: Color { Color(atomic: "Lime/80") }
    /// Figma atomic `Lime/37` (#429E00).
    static var mhLime37: Color { Color(atomic: "Lime/37") }

    /// Figma atomic `Green/90` (#ACFCC7).
    static var mhGreen90: Color { Color(atomic: "Green/90") }
    /// Figma atomic `Green/60` (#1ED45A).
    static var mhGreen60: Color { Color(atomic: "Green/60") }

    /// Figma atomic `Cyan/90` (#B5F4FF).
    static var mhCyan90: Color { Color(atomic: "Cyan/90") }
    /// Figma atomic `Cyan/50` (#00BDDE).
    static var mhCyan50: Color { Color(atomic: "Cyan/50") }

    /// Figma atomic `Violet/80` (#C0B0FF).
    static var mhViolet80: Color { Color(atomic: "Violet/80") }
    /// Figma atomic `Violet/50` (#6541F2).
    static var mhViolet50: Color { Color(atomic: "Violet/50") }

    /// Figma atomic `Pink/90` (#FED3F7).
    static var mhPink90: Color { Color(atomic: "Pink/90") }
    /// Figma atomic `Pink/60` (#FA73E3).
    static var mhPink60: Color { Color(atomic: "Pink/60") }

    /// Figma atomic `Blue/65` (#4F95FF).
    static var mhBlue65: Color { Color(atomic: "Blue/65") }
    /// Figma atomic `Blue/40` (#0054D1).
    static var mhBlue40: Color { Color(atomic: "Blue/40") }

    /// Brown 은 Figma 스와치에 변수가 바인딩돼 있지 않아 렌더에서 실측했다(#DBA679).
    /// 단계 번호는 이웃 계열 패턴을 따른 잠정값 — 디자인팀이 변수를 붙이면 이름을 맞춘다.
    static var mhBrown70: Color { Color(atomic: "Brown/70") }
    /// Brown 실측값(#B96013). 위와 같은 이유로 단계 번호는 잠정.
    static var mhBrown40: Color { Color(atomic: "Brown/40") }

    /// Figma atomic `Light Blue/60` (#3DC2FF).
    static var mhLightBlue60: Color { Color(atomic: "Light Blue/60") }
    /// Figma atomic `Light Blue/40` (#008DCF).
    static var mhLightBlue40: Color { Color(atomic: "Light Blue/40") }

    /// Figma atomic `Purple/70` (#DE96FF).
    static var mhPurple70: Color { Color(atomic: "Purple/70") }
    /// Figma atomic `Purple/40` (#AD36E3).
    static var mhPurple40: Color { Color(atomic: "Purple/40") }
}
