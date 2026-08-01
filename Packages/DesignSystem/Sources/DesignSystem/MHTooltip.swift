import SwiftUI

// MARK: - Tooltip

/// 툴팁 크기. Figma `size` = Medium(본문 14) / Small(캡션 11, 데스크톱 보조).
public enum MHTooltipSize: Sendable { case medium, small }

/// 툴팁이 앵커 기준 어디에 뜨는지 = 화살표가 붙는 변. Figma `position`.
/// `bottom`=앵커 아래(화살표 위·↑) / `top`=위(↓) / `left`=왼쪽(→) / `right`=오른쪽(←).
public enum MHTooltipPosition: Sendable { case top, bottom, left, right }

/// 화살표가 변을 따라 놓이는 위치. Figma `align`.
/// top/bottom 변에선 leading/center/trailing, left/right 변에선 top/center/bottom 을 의미.
public enum MHTooltipAlign: Sendable { case start, center, end }

/// UI 요소에 대한 짧은 레이블/보조 정보를 띄우는 다크 말풍선(+화살표). Figma `Tooltip/Tooltip`.
///
/// 반투명 어두운 버블(`Inverse/Background` 88% + 검정 5%)에 흰 텍스트를 얹고, `position` 변에 삼각
/// 화살표를 붙여 앵커를 가리킨다. `shortcut`(예: `⌘C`)을 주면 우측에 옅게 표시한다. 시각 컴포넌트로,
/// 실제 앵커 위 배치는 호출부가 담당한다.
///
/// > 배경 블러(Figma backdrop-blur 32)는 iOS 근사 생략(반투명 플랫). `MHSnackbar`/`MHTextArea` 와 동일 한계.
///
/// ```swift
/// MHTooltip("메시지에 마침표를 찍어요.")                                  // Medium·아래·중앙
/// MHTooltip("역할", size: .small, position: .right)                       // Small·오른쪽 화살표
/// MHTooltip("복사", shortcut: "⌘C", position: .top, align: .start)        // 단축키 + 화살표 leading
/// ```
public struct MHTooltip: View {
    private let label: String
    private let shortcut: String?
    private let size: MHTooltipSize
    private let position: MHTooltipPosition
    private let align: MHTooltipAlign

    public init(
        _ label: String,
        shortcut: String? = nil,
        size: MHTooltipSize = .medium,
        position: MHTooltipPosition = .bottom,
        align: MHTooltipAlign = .center
    ) {
        self.label = label
        self.shortcut = shortcut
        self.size = size
        self.position = position
        self.align = align
    }

    private var m: Metric { Metric(size) }

    public var body: some View {
        bubble
            .padding(arrowEdge, m.arrowH)                       // 화살표 자리 확보
            .overlay(alignment: overlayAlignment) { arrowView }
    }

    // 말풍선 본체(배경 + 텍스트).
    private var bubble: some View {
        HStack(spacing: m.shortcutGap) {
            // 툴팁은 짧은 레이블이 기본 — 단일 라인 hug(shortcut 형제가 폭을 압축해 줄바꿈되는 것 방지).
            // 아주 긴 텍스트의 max-w 256 줄바꿈은 미적용(툴팁 용법상 드묾).
            Text(label)
                .mhTypography(m.font)
                .foregroundStyle(.mhInverseLabel)
                .fixedSize(horizontal: true, vertical: false)
            if let shortcut {
                Text(shortcut)
                    .mhTypography(m.font)
                    .foregroundStyle(.mhInverseLabel)
                    .opacity(0.61)                             // Figma Opacity/61
                    .fixedSize()
            }
        }
        .frame(minHeight: m.lineHeight)                        // SUITE intrinsic < Figma 라인박스 → 고정(칩·버튼과 동일)
        .padding(.horizontal, m.hPad)
        .padding(.vertical, m.vPad)
        .frame(minWidth: m.minWidth, alignment: .leading)
        .background(fillBackground)
        .clipShape(RoundedRectangle(cornerRadius: m.radius))
    }

    // 배경 2겹(Inverse/Background 88% + 검정 5%).
    private var fillBackground: some View {
        ZStack {
            Color.mhInverseBackground.opacity(0.88)            // Figma Opacity/88
            Color.black.opacity(0.05)                          // Figma Primary/Normal Opacity/5
        }
    }

    // 삼각 화살표 — position 변에 붙어 앵커를 가리킨다. align 으로 변을 따라 이동(끝 정렬은 8/5pt 인셋).
    private var arrowView: some View {
        let horizontal = position == .left || position == .right
        return TooltipArrow(position: position)
            .fill(Color.mhInverseBackground.opacity(0.88))
            .overlay { TooltipArrow(position: position).fill(Color.black.opacity(0.05)) }
            .frame(
                width: horizontal ? m.arrowH : m.arrowW,
                height: horizontal ? m.arrowW : m.arrowH
            )
            .frame(
                maxWidth: horizontal ? nil : .infinity,
                maxHeight: horizontal ? .infinity : nil,
                alignment: arrowAlignment
            )
            .padding(horizontal ? .vertical : .horizontal, m.arrowInset)
    }

    // 화살표가 놓이는 변(패딩 방향).
    private var arrowEdge: Edge.Set {
        switch position {
        case .bottom: return .top
        case .top:    return .bottom
        case .left:   return .trailing
        case .right:  return .leading
        }
    }

    // overlay 를 확보한 화살표 자리(변)에 붙인다.
    private var overlayAlignment: Alignment {
        switch position {
        case .bottom: return .top
        case .top:    return .bottom
        case .left:   return .trailing
        case .right:  return .leading
        }
    }

    // 변을 따라 화살표 정렬(start/center/end → leading·top / center / trailing·bottom).
    private var arrowAlignment: Alignment {
        let horizontal = position == .left || position == .right
        switch (align, horizontal) {
        case (.center, _):     return .center
        case (.start, false):  return .leading
        case (.end, false):    return .trailing
        case (.start, true):   return .top
        case (.end, true):     return .bottom
        }
    }

    // 크기별 수치(Figma 실측).
    private struct Metric {
        let font: MHTypography
        let hPad, vPad, radius, minWidth, lineHeight: CGFloat
        let arrowW, arrowH, arrowInset, shortcutGap: CGFloat
        init(_ size: MHTooltipSize) {
            switch size {
            case .medium:   // 라인박스 14×1.429≈20
                font = .label1NormalMedium; hPad = 12; vPad = 8; radius = 8; minWidth = 64; lineHeight = 20
                arrowW = 20; arrowH = 8; arrowInset = 8; shortcutGap = 6
            case .small:    // 라인박스 11×1.273≈14
                font = .caption2Medium; hPad = 8; vPad = 5; radius = 6; minWidth = 36; lineHeight = 14
                arrowW = 14; arrowH = 6; arrowInset = 5; shortcutGap = 4
            }
        }
    }
}

// MARK: - Arrow Shape

// position 변에서 바깥(앵커)을 향하는 삼각형. rect 는 화살표 프레임(가로/세로 배치는 호출부 frame 이 결정).
struct TooltipArrow: Shape {
    let position: MHTooltipPosition
    func path(in r: CGRect) -> Path {
        var p = Path()
        switch position {
        case .bottom:   // 위 변, 위(↑)를 가리킴
            p.move(to: CGPoint(x: r.midX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        case .top:      // 아래 변, 아래(↓)
            p.move(to: CGPoint(x: r.midX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        case .left:     // 오른 변, 오른쪽(→)
            p.move(to: CGPoint(x: r.maxX, y: r.midY))
            p.addLine(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        case .right:    // 왼 변, 왼쪽(←)
            p.move(to: CGPoint(x: r.minX, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        }
        p.closeSubpath()
        return p
    }
}
