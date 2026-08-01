import SwiftUI

// Figma `Atomic/*` 팔레트. 시맨틱 토큰(`Color.mh*`)과 다른 계층이다 —
// 시맨틱은 역할(Label/Line/Background…)에 묶여 라이트·다크로 갈리지만,
// Atomic 은 색 그 자체라 모드 분기 없이 절대값 하나를 쓴다.
//
// 역할이 정해진 곳에는 시맨틱 토큰을 쓴다. Atomic 은 **사용자가 색을 직접 고르는 팔레트**처럼
// 색상 자체가 데이터인 자리에서만 쓴다(예: 방 색상 선택).
//
// 계열마다 밝은 단계(채움)와 진한 단계(테두리) 한 쌍씩만 등록돼 있다 — 현재 쓰이는 조합이 그뿐이다.
// 단계 번호는 Figma 변수명 그대로다(`Atomic/Red/60` → `mhAtomicRed60`).

fileprivate extension Color {
    init(atomic name: String) { self.init(name, bundle: .module) }
}

public extension ShapeStyle where Self == Color {
    /// Figma `Atomic/Red/60`
    static var mhAtomicRed60: Color { Color(atomic: "Red/60") }
    /// Figma `Atomic/Red/30`
    static var mhAtomicRed30: Color { Color(atomic: "Red/30") }

    /// Figma `Atomic/Red Orange/70`
    static var mhAtomicRedOrange70: Color { Color(atomic: "Red Orange/70") }
    /// Figma `Atomic/Red Orange/40`
    static var mhAtomicRedOrange40: Color { Color(atomic: "Red Orange/40") }

    /// Figma `Atomic/Orange/70`
    static var mhAtomicOrange70: Color { Color(atomic: "Orange/70") }
    /// Figma `Atomic/Orange/40`
    static var mhAtomicOrange40: Color { Color(atomic: "Orange/40") }

    /// Figma `Atomic/Lime/80`
    static var mhAtomicLime80: Color { Color(atomic: "Lime/80") }
    /// Figma `Atomic/Lime/37`
    static var mhAtomicLime37: Color { Color(atomic: "Lime/37") }

    /// Figma `Atomic/Green/90`
    static var mhAtomicGreen90: Color { Color(atomic: "Green/90") }
    /// Figma `Atomic/Green/60`
    static var mhAtomicGreen60: Color { Color(atomic: "Green/60") }

    /// Figma `Atomic/Cyan/90`
    static var mhAtomicCyan90: Color { Color(atomic: "Cyan/90") }
    /// Figma `Atomic/Cyan/50`
    static var mhAtomicCyan50: Color { Color(atomic: "Cyan/50") }

    /// Figma `Atomic/Violet/80`
    static var mhAtomicViolet80: Color { Color(atomic: "Violet/80") }
    /// Figma `Atomic/Violet/50`
    static var mhAtomicViolet50: Color { Color(atomic: "Violet/50") }

    /// Figma `Atomic/Pink/90`
    static var mhAtomicPink90: Color { Color(atomic: "Pink/90") }
    /// Figma `Atomic/Pink/60`
    static var mhAtomicPink60: Color { Color(atomic: "Pink/60") }

    /// Figma `Atomic/Blue/65`
    static var mhAtomicBlue65: Color { Color(atomic: "Blue/65") }
    /// Figma `Atomic/Blue/40`
    static var mhAtomicBlue40: Color { Color(atomic: "Blue/40") }

    /// Brown 은 Figma 스와치에 변수가 바인딩돼 있지 않아 렌더에서 실측했다(#DBA679).
    /// 단계 번호는 이웃 계열 패턴을 따른 잠정값 — 디자인팀이 변수를 붙이면 이름을 맞춘다.
    static var mhAtomicBrown70: Color { Color(atomic: "Brown/70") }
    /// Brown 실측값(#B96013). 위와 같은 이유로 단계 번호는 잠정.
    static var mhAtomicBrown40: Color { Color(atomic: "Brown/40") }

    /// Figma `Atomic/Light Blue/60`
    static var mhAtomicLightBlue60: Color { Color(atomic: "Light Blue/60") }
    /// Figma `Atomic/Light Blue/40`
    static var mhAtomicLightBlue40: Color { Color(atomic: "Light Blue/40") }

    /// Figma `Atomic/Purple/70`
    static var mhAtomicPurple70: Color { Color(atomic: "Purple/70") }
    /// Figma `Atomic/Purple/40`
    static var mhAtomicPurple40: Color { Color(atomic: "Purple/40") }
}
