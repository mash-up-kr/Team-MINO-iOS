import SwiftUI
import UIKit

/// 그림자 잉크 `#171717`. Figma에서 라이트/다크 동일하게 고정이라 시맨틱 토큰이 아니다.
private func shadowInk(_ opacity: Double) -> Color {
    Color(red: 0x17 / 255, green: 0x17 / 255, blue: 0x17 / 255, opacity: opacity)
}

/// Figma blur → iOS shadowRadius. iOS의 blur는 CSS/Figma의 2배라 절반으로 변환한다.
/// (CSS가 blur를 표준편차의 2배로 정의 — bjango. `.shadow`/CALayer 계열에 적용되는 확립된 값.)
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

// MARK: - Normal (음수 spread, 다층) — CALayer + shadowPath

/// Elevation 그림자(`Shadow/Normal/*`, 음수 spread, 1~2 layer). CALayer의 `shadowPath`로 spread를
/// 정확히 반영하고, layer마다 sublayer를 쌓아 다층을 그린다. 불투명 표면 뒤에 두며, 표면과 같은
/// `cornerRadius`를 넘긴다.
public enum MHShadow: Sendable, CaseIterable {
    case xsmall, small, medium, large, xlarge

    /// Figma DROP_SHADOW layer 하나. 값은 Figma 그대로(음수 spread는 그림자를 줄인다).
    struct Layer: Sendable {
        let color: Color
        let x: CGFloat
        let y: CGFloat
        let blur: CGFloat
        let spread: CGFloat
    }

    var layers: [Layer] {
        switch self {
        case .xsmall:
            [Layer(color: shadowInk(0.10), x: 0, y: 1, blur: 2, spread: -1)]
        case .small:
            [Layer(color: shadowInk(0.06), x: 0, y: 4, blur: 6, spread: -1),
             Layer(color: shadowInk(0.06), x: 0, y: 2, blur: 4, spread: -2)]
        case .medium:
            [Layer(color: shadowInk(0.07), x: 0, y: 10, blur: 15, spread: -3),
             Layer(color: shadowInk(0.07), x: 0, y: 4, blur: 6, spread: -2)]
        case .large:
            [Layer(color: shadowInk(0.08), x: 0, y: 16, blur: 24, spread: -6),
             Layer(color: shadowInk(0.08), x: 0, y: 6, blur: 10, spread: -4)]
        case .xlarge:
            [Layer(color: shadowInk(0.12), x: 0, y: 24, blur: 38, spread: -10),
             Layer(color: shadowInk(0.10), x: 0, y: 10, blur: 15, spread: -5)]
        }
    }
}

/// 각 Figma layer를 CALayer 하나로 그린다. `shadowPath`(표면을 spread만큼 넓힌 rounded rect)로
/// spread를 반영하고, blur는 `shadowRadius = blur/2`로 넣는다.
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
            caster.shadowRadius = shadowRadius(spec.blur)
            layer.addSublayer(caster)
            return caster
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for (caster, spec) in zip(casters, layerSpecs) {
            caster.frame = bounds
            // CSS spread: 그림자 상자 = border 상자를 spread만큼 확장(음수면 축소)
            let rect = bounds.insetBy(dx: -spec.spread, dy: -spec.spread)
            let radius = max(0, cornerRadius + spec.spread)
            caster.shadowPath = UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath
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
