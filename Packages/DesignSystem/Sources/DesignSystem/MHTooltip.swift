import SwiftUI

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
    private let maxWidth: CGFloat?

    public init(
        _ label: String,
        shortcut: String? = nil,
        size: MHTooltipSize = .medium,
        position: MHTooltipPosition = .bottom,
        align: MHTooltipAlign = .center,
        maxWidth: CGFloat? = nil
    ) {
        self.label = label
        self.shortcut = shortcut
        self.size = size
        self.position = position
        self.align = align
        self.maxWidth = maxWidth
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
            // `maxWidth` 를 주면 그 폭에서 줄바꿈한다(Figma 인스턴스가 폭을 고정한 경우).
            labelText
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
        // maxWidth 는 **툴팁 전체**(화살표 포함) 기준으로 받는다 — 시안에서 재는 값이 그것이라
        // 화살표가 붙는 변만큼 빼서 말풍선에 건다. 안 주면(nil) 지금까지처럼 무제한 hug.
        .frame(minWidth: m.minWidth, maxWidth: bubbleMaxWidth, alignment: .leading)
        .background(fillBackground)
        .clipShape(RoundedRectangle(cornerRadius: m.radius))
    }

    // 레이블 — 줄바꿈 여부(maxWidth)에 따라 행간 처리가 갈린다.
    @ViewBuilder private var labelText: some View {
        if maxWidth == nil {
            // 단일 라인 hug: 폰트·자간만 넣는 `Text` 오버로드 + 말풍선의 `minHeight` 가 라인박스를 잡는다.
            // 행간까지 붙이는 View 쪽 모디파이어를 걸면 세로 패딩이 더해져 높이가 1pt 커진다
            // (Figma 실측 42/29 를 지키는 `MHTooltipSnapshotTests` 가 이를 잡는다).
            Text(label)
                .mhTypography(m.font)
                .foregroundStyle(.mhInverseLabel)
                .fixedSize(horizontal: true, vertical: false)
        } else {
            // 줄바꿈 허용: 시안 라인박스(medium 20)대로 줄을 벌려야 2줄 높이가 시안과 맞는다
            // (SUITE intrinsic 이 시안보다 작아 그냥 두면 둘째 줄이 붙는다).
            Text(label)
                .foregroundStyle(.mhInverseLabel)
                .modifier(MHTypographyModifier(style: m.font))
        }
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

    // 말풍선 자체의 최대 폭 — 전체 폭에서 화살표가 차지하는 변(좌/우일 때만 가로)을 뺀다.
    private var bubbleMaxWidth: CGFloat? {
        guard let maxWidth else { return nil }
        return position == .left || position == .right ? maxWidth - m.arrowH : maxWidth
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
            case .medium:   // 라인박스 14×1.429≈20. 화살표 리소스 20×5.924(≈6)
                font = .label1NormalMedium; hPad = 12; vPad = 8; radius = 8; minWidth = 64; lineHeight = 20
                arrowW = 20; arrowH = 6; arrowInset = 8; shortcutGap = 6
            case .small:    // 라인박스 11×1.273≈14. 화살표 리소스 14×5
                font = .caption2Medium; hPad = 8; vPad = 5; radius = 6; minWidth = 36; lineHeight = 14
                arrowW = 14; arrowH = 5; arrowInset = 5; shortcutGap = 4
            }
        }
    }
}

// MARK: - Arrow Shape

// Figma `Tooltip/Resource/*/Arrow` 곡선 화살표 — 밑변이 부드럽게 벌어지고 꼭짓점이 둥근 형태(단순 삼각형 아님).
// Medium 리소스 SVG(20×5.924) 를 단위좌표로 정규화한 베지어를 그대로 옮겼다(xn: 밑변 방향, yn: 0=꼭짓점(바깥)/1=밑변(버블면)).
// 4방향은 정규화 좌표를 rect 에 매핑해 처리(가로 position 은 rect 가 깊이×밑변 으로 들어온다).
struct TooltipArrow: Shape {
    let position: MHTooltipPosition

    func path(in rect: CGRect) -> Path {
        // (xn, yn) 단위좌표 → rect. yn=0 은 꼭짓점(바깥/앵커쪽), yn=1 은 밑변(버블에 붙는 면).
        func pt(_ xn: CGFloat, _ yn: CGFloat) -> CGPoint {
            switch position {
            case .bottom: return CGPoint(x: xn * rect.width, y: yn * rect.height)             // ↑ 꼭짓점 위
            case .top:    return CGPoint(x: xn * rect.width, y: (1 - yn) * rect.height)        // ↓ 꼭짓점 아래
            case .left:   return CGPoint(x: (1 - yn) * rect.width, y: xn * rect.height)        // → 꼭짓점 오른쪽
            case .right:  return CGPoint(x: yn * rect.width, y: xn * rect.height)              // ← 꼭짓점 왼쪽
            }
        }
        var p = Path()
        p.move(to: pt(0.295906, 0.622709))
        p.addLine(to: pt(0.378519, 0.297323))
        p.addCurve(to: pt(0.466193, 0.019879), control1: pt(0.420368, 0.132491), control2: pt(0.441293, 0.050076))
        p.addCurve(to: pt(0.533805, 0.019879), control1: pt(0.488048, -0.006626), control2: pt(0.511955, -0.006626)) // 둥근 꼭짓점
        p.addCurve(to: pt(0.621480, 0.297323), control1: pt(0.558705, 0.050076), control2: pt(0.579630, 0.132491))
        p.addLine(to: pt(0.704095, 0.622709))
        p.addCurve(to: pt(0.778450, 0.881068), control1: pt(0.739370, 0.761642), control2: pt(0.757005, 0.831114))
        p.addCurve(to: pt(0.840885, 0.977811), control1: pt(0.797450, 0.925182), control2: pt(0.818575, 0.957938))
        p.addCurve(to: pt(0.913570, 0.999796), control1: pt(0.860195, 0.995012), control2: pt(0.880640, 0.998967))
        p.addLine(to: pt(1.0, 0.999796))
        p.addLine(to: pt(0.0, 0.999796))                                                        // 밑변(버블면)
        p.addLine(to: pt(0.086431, 0.999796))
        p.addCurve(to: pt(0.159113, 0.977811), control1: pt(0.119362, 0.998967), control2: pt(0.139803, 0.995012))
        p.addCurve(to: pt(0.221551, 0.881068), control1: pt(0.181424, 0.957938), control2: pt(0.202549, 0.925182))
        p.addCurve(to: pt(0.295906, 0.622709), control1: pt(0.242995, 0.831114), control2: pt(0.260632, 0.761642))
        p.closeSubpath()
        return p
    }
}

// Figma `Tooltip/Tooltip` 매트릭스 — Size(Medium/Small) × Position(Bottom/Top/Left/Right).
// 열: Medium("메시지에 마침표를 찍어요.") / Small("역할"). 행: Bottom·Top·Left·Right.
// 화살표 정렬은 Figma 예제 기본값인 start(leading, 인셋 8/5pt)에 맞춘다(실측: 화살표가 leading).
#Preview("MHTooltip · Figma 매트릭스") {
    Grid(alignment: .leading, horizontalSpacing: 48, verticalSpacing: 28) {
        GridRow {
            MHTooltip("메시지에 마침표를 찍어요.", position: .bottom, align: .start)
            MHTooltip("역할", size: .small, position: .bottom, align: .start)
        }
        GridRow {
            MHTooltip("메시지에 마침표를 찍어요.", position: .top, align: .start)
            MHTooltip("역할", size: .small, position: .top, align: .start)
        }
        GridRow {
            MHTooltip("메시지에 마침표를 찍어요.", position: .left, align: .start)
            MHTooltip("역할", size: .small, position: .left, align: .start)
        }
        GridRow {
            MHTooltip("메시지에 마침표를 찍어요.", position: .right, align: .start)
            MHTooltip("역할", size: .small, position: .right, align: .start)
        }
    }
    .padding(40)
}

// Figma 축 밖의 인스턴스 옵션: align(화살표가 변을 따라 start/center/end 이동) · shortcut(단축키).
// 단축키 예시는 Figma 기본 정렬 start(화살표가 라벨 아래)로 둔다.
#Preview("MHTooltip · 옵션") {
    VStack(alignment: .leading, spacing: 28) {
        HStack(spacing: 24) {
            MHTooltip("start", position: .bottom, align: .start)
            MHTooltip("center", position: .bottom, align: .center)
            MHTooltip("end", position: .bottom, align: .end)
        }
        MHTooltip("복사", shortcut: "⌘C", position: .top, align: .start)
        MHTooltip("붙여넣기", shortcut: "⌘V", size: .small, position: .top, align: .start)
    }
    .padding(40)
}
