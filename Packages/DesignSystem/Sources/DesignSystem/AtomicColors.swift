import SwiftUI

// MARK: - 애터믹(팔레트) 컬러
//
// 원칙적으로 화면·컴포넌트는 시맨틱 토큰(`Color.mh*` in SemanticColors)만 쓴다.
// 다만 Figma 가 **대응하는 시맨틱 토큰 없이 애터믹 팔레트 색을 직접 쓴 경우**(예: 특정 일러스트 배경),
// hex/rgb 를 코드에 박지 않고 여기에 **Figma 이름 그대로** 에셋으로 등록해 토큰으로 쓴다.
// (`AtomicColor.xcassets` 에 colorset 추가 → 아래에 접근자 추가)
//
// 애터믹은 팔레트 원시값이라 라이트/다크 구분 없이 단일값이다.

fileprivate extension Color {
    init(atomic name: String) { self.init(name, bundle: .module) }
}

public extension ShapeStyle where Self == Color {
    /// Figma atomic `Pink/95` (#FEECFB).
    static var mhPink95: Color { Color(atomic: "Pink/95") }
    /// Figma atomic `Purple/95` (#F9EDFF).
    static var mhPurple95: Color { Color(atomic: "Purple/95") }
    /// Figma atomic `Violet/95` (#F0ECFE).
    static var mhViolet95: Color { Color(atomic: "Violet/95") }
    /// Figma atomic `Blue/95` (#EAF2FE).
    static var mhBlue95: Color { Color(atomic: "Blue/95") }
    /// Figma atomic `Light Blue/95` (#E5F6FE).
    static var mhLightBlue95: Color { Color(atomic: "Light Blue/95") }
    /// Figma atomic `Cyan/95` (#DEFAFF).
    static var mhCyan95: Color { Color(atomic: "Cyan/95") }
    /// Figma atomic `Green/95` (#D9FFE6).
    static var mhGreen95: Color { Color(atomic: "Green/95") }
    /// Figma atomic `Lime/95` (#E6FFD4).
    static var mhLime95: Color { Color(atomic: "Lime/95") }
    /// Figma atomic `Orange/95` (#FEF4E6).
    static var mhOrange95: Color { Color(atomic: "Orange/95") }
    /// Figma atomic `Red Orange/95` (#FEEEE5).
    static var mhRedOrange95: Color { Color(atomic: "Red Orange/95") }
}
