import SwiftUI
import UIKit

/// 그림자 잉크 `#171717`. Figma에서 라이트/다크 동일하게 고정이라 시맨틱 토큰이 아니다.
private func shadowInk(_ opacity: Double) -> Color {
    Color(red: 0x17 / 255, green: 0x17 / 255, blue: 0x17 / 255, opacity: opacity)
}

/// CSS/Figma blur → iOS shadowRadius(절반). **Spread 전용** — Figma가 Spread엔 iOS Value를 따로
/// 주지 않아 CSS blur에서 변환한다(CSS는 blur를 표준편차의 2배로 정의 — bjango).
/// Normal은 Figma "iOS Value" 열의 radius를 그대로 쓴다(변환 없음).
private func shadowRadius(_ blur: CGFloat) -> CGFloat { blur / 2 }

// MARK: - Spread (spread 0, 단일 layer) — 네이티브 `.shadow`

/// "Spread" glow 그림자(`Shadow/Spread/*`, spread 0, 단일 layer). spread가 없고 layer가 하나라
/// 네이티브 `.shadow(radius: blur/2)`로 정확히 그려지며 shape 제약이 없다.
public enum MHSpreadShadow: Sendable, CaseIterable {
    case small, medium

    struct Spec: Sendable {
        let color: Color
        let x: CGFloat
        let y: CGFloat
        let blur: CGFloat
    }

    var spec: Spec {
        switch self {
        case .small:  Spec(color: shadowInk(0.10), x: 0, y: 0, blur: 60)
        case .medium: Spec(color: shadowInk(0.16), x: 0, y: 15, blur: 75)
        }
    }
}

public extension View {
    /// "Spread" glow 그림자를 적용한다. 네이티브 `.shadow`라 어떤 shape에나 그려진다.
    ///
    /// ```swift
    /// FloatingButton()
    ///     .mhShadow(spread: .medium)
    /// ```
    func mhShadow(spread shadow: MHSpreadShadow) -> some View {
        let s = shadow.spec
        return self.shadow(color: s.color, radius: shadowRadius(s.blur), x: s.x, y: s.y)
    }
}

// MARK: - Normal (다층) — CALayer + shadowPath

/// Elevation 그림자(`Shadow/Normal/*`, 1~2 layer). 값은 Figma "iOS Value" 열 그대로다 —
/// `radius`가 이미 iOS shadowRadius 최종값이라 blur/2 변환을 하지 않고, iOS Value엔 spread도 없다.
/// layer마다 sublayer를 쌓아 다층을 그리고, `shadowPath`로 표면 모양(cornerRadius)을 잡는다.
/// 불투명 표면 뒤에 두며, 표면과 같은 `cornerRadius`를 넘긴다.
public enum MHShadow: Sendable, CaseIterable {
    case xsmall, small, medium, large, xlarge

    /// Figma "iOS Value" 열의 layer 하나. `radius`는 iOS shadowRadius 최종값(변환 불필요).
    struct Layer: Sendable {
        let color: Color
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
    }

    var layers: [Layer] {
        switch self {
        case .xsmall:
            [Layer(color: shadowInk(0.10), x: 0, y: 1, radius: 0.5)]
        case .small:
            [Layer(color: shadowInk(0.03), x: 0, y: 2, radius: 1),
             Layer(color: shadowInk(0.03), x: 0, y: 4, radius: 2.5)]
        case .medium:
            [Layer(color: shadowInk(0.035), x: 0, y: 4, radius: 2),
             Layer(color: shadowInk(0.035), x: 0, y: 10, radius: 6)]
        case .large:
            [Layer(color: shadowInk(0.04), x: 0, y: 6, radius: 3),
             Layer(color: shadowInk(0.04), x: 0, y: 16, radius: 9)]
        case .xlarge:
            [Layer(color: shadowInk(0.05), x: 0, y: 10, radius: 5),
             Layer(color: shadowInk(0.06), x: 0, y: 24, radius: 14)]
        }
    }
}

/// 각 Figma layer를 CALayer 하나로 그린다. `shadowPath`(표면 rounded rect)로 모양을 잡고,
/// `radius`(iOS Value 최종값)를 그대로 `shadowRadius`에 넣는다.
final class MHShadowUIView: UIView {
    var layerSpecs: [MHShadow.Layer] = [] { didSet { rebuild() } }
    var cornerRadius: CGFloat = 0 { didSet { setNeedsLayout() } }

    private var casters: [CALayer] = []

    private func rebuild() {
        casters.forEach { $0.removeFromSuperlayer() }
        casters = layerSpecs.map { spec in
            let caster = CALayer()
            caster.shadowColor = UIColor(spec.color).cgColor  // 알파는 색에 포함
            caster.shadowOpacity = 1
            caster.shadowOffset = CGSize(width: spec.x, height: spec.y)
            caster.shadowRadius = spec.radius
            layer.addSublayer(caster)
            return caster
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        for caster in casters {
            caster.frame = bounds
            caster.shadowPath = path
        }
    }
}

private struct MHShadowBackground: UIViewRepresentable {
    let shadow: MHShadow
    let cornerRadius: CGFloat

    func makeUIView(context: Context) -> MHShadowUIView {
        let view = MHShadowUIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: MHShadowUIView, context: Context) {
        view.layerSpecs = shadow.layers
        view.cornerRadius = cornerRadius
    }
}

public extension View {
    /// rounded surface 뒤에 elevation 그림자를 넣는다. spread·다층이 제대로 그려지도록
    /// 표면의 `cornerRadius`를 함께 넘긴다(`0` = 사각형). 불투명 표면(카드·시트)에 쓴다.
    ///
    /// ```swift
    /// Card()
    ///     .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    ///     .mhShadow(.large, cornerRadius: 12)
    /// ```
    func mhShadow(_ shadow: MHShadow, cornerRadius: CGFloat = 0) -> some View {
        background(MHShadowBackground(shadow: shadow, cornerRadius: cornerRadius))
    }
}
