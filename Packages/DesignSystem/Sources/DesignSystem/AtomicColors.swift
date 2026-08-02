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
    /// Figma atomic `Pink/95` (#FEECFB). 방 기본 썸네일 배경 등에 쓰인다.
    static var mhPink95: Color { Color(atomic: "Pink/95") }
}
