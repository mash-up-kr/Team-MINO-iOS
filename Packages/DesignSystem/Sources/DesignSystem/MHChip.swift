import SwiftUI

// MARK: - Chip

/// 배경·테두리 스타일. `solid`(채운 배경) / `outlined`(테두리만).
public enum MHChipVariant: Sendable { case solid, outlined }
/// 크기 프리셋. 폰트·패딩·radius·아이콘 크기가 함께 정해진다.
public enum MHChipSize: Sendable { case xsmall, small, medium, large }

/// 칩의 leading/trailing 슬롯 콘텐츠. 단색 아이콘 또는 썸네일(1:1 이미지).
public enum MHChipContent {
    /// 시맨틱 아이콘(템플릿 렌더 — 콘텐츠 색으로 틴트됨).
    case icon(MHIcon)
    /// 썸네일 등 임의 이미지(1:1, 틴트하지 않음).
    case image(Image)
}

/// 항목을 제어·선택하거나 후속 액션을 거는 낮은 위계의 Action Chip. Figma `Chip/Chip`.
///
/// ``MHChipVariant``(Solid/Outlined) × ``MHChipSize``(XS/S/M/L) 축에 `isActive`·`disabled`·
/// leading/trailing 콘텐츠를 조합한다. 색은 시맨틱 토큰을 참조하되, `contentColor`·`backgroundColor`·
/// `activeColor` 로 기본 토큰을 덮어쓸 수 있다(Figma customize 축).
///
/// ```swift
/// MHChip("전체") { toggle() }                                   // 기본: solid·medium·비활성
/// MHChip("최신순", isActive: vm.isLatest) { vm.pick(.latest) }  // 활성(선택) 상태
/// MHChip("필터", variant: .outlined, leading: .icon(.tune)) { openFilter() }
/// MHChip("스타트업", leading: .image(logo)) { open() }          // 썸네일 콘텐츠
/// MHChip("삭제", size: .small) { remove() }.disabled(true)      // 표준 .disabled
/// ```
public struct MHChip: View {
    private let text: String
    private let variant: MHChipVariant
    private let size: MHChipSize
    private let isActive: Bool
    private let leading: MHChipContent?
    private let trailing: MHChipContent?
    private let contentColor: Color?
    private let backgroundColor: Color?
    private let activeColor: Color?
    private let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    public init(
        _ text: String,
        variant: MHChipVariant = .solid,
        size: MHChipSize = .medium,
        isActive: Bool = false,
        leading: MHChipContent? = nil,
        trailing: MHChipContent? = nil,
        contentColor: Color? = nil,
        backgroundColor: Color? = nil,
        activeColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.variant = variant
        self.size = size
        self.isActive = isActive
        self.leading = leading
        self.trailing = trailing
        self.contentColor = contentColor
        self.backgroundColor = backgroundColor
        self.activeColor = activeColor
        self.action = action
    }

    public var body: some View {
        Button(action: action) { content }
            .buttonStyle(
                MHChipStyle(
                    spec: MHChipSpec(
                        variant: variant, size: size, isActive: isActive,
                        contentColor: contentColor, backgroundColor: backgroundColor, activeColor: activeColor
                    ),
                    isEnabled: isEnabled
                )
            )
    }

    @ViewBuilder private var content: some View {
        let metric = size.metric
        HStack(spacing: metric.gap) {
            if let leading { slot(leading, size: metric.iconSize) }
            // 텍스트는 Figma text Wrapper(px) 만큼 좌우 패딩. 칩은 콘텐츠를 hug 하므로
            // 좁은 부모에서도 압축·… 로 잘리지 않도록 fixedSize 로 고정.
            Text(text).mhTypography(metric.font)
                .padding(.horizontal, metric.textHPadding)
                .fixedSize(horizontal: true, vertical: false)
            if let trailing { slot(trailing, size: metric.iconSize) }
        }
    }

    // 아이콘은 템플릿(콘텐츠 색으로 틴트), 이미지는 원본(틴트 없음)으로 정사각 렌더.
    @ViewBuilder private func slot(_ content: MHChipContent, size: CGFloat) -> some View {
        switch content {
        case .icon(let icon):
            Image(icon).resizable().frame(width: size, height: size)
        case .image(let image):
            image.resizable().aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 1))
        }
    }
}

// MARK: - Spec (Figma 토큰 매핑)

struct MHChipSpec {
    let variant: MHChipVariant
    let size: MHChipSize
    let isActive: Bool
    let contentColor: Color?
    let backgroundColor: Color?
    let activeColor: Color?

    // 활성 강조색: Solid=Label/Strong(검정), Outlined=Primary/Normal. activeColor 로 덮어쓸 수 있다.
    var activeAccent: Color { activeColor ?? (variant == .solid ? .mhLabelStrong : .mhPrimaryNormal) }

    // 텍스트·아이콘 색.
    func foreground(isEnabled: Bool) -> Color {
        guard isEnabled else { return .mhLabelDisable }
        if isActive {
            return variant == .solid ? .mhInverseLabel : activeAccent   // Solid 활성은 반전색, Outlined 활성은 강조색
        }
        return contentColor ?? .mhLabelAlternative
    }

    // 배경 채움.
    func background(isEnabled: Bool) -> Color {
        guard isEnabled else { return variant == .solid ? .mhInteractionDisable : .clear }
        switch (variant, isActive) {
        case (.solid, false):    return backgroundColor ?? .mhFillAlternative
        case (.solid, true):     return activeAccent                 // 검정(또는 activeColor)
        case (.outlined, false): return .clear
        case (.outlined, true):  return activeAccent.opacity(0.05)   // 옅은 강조 틴트
        }
    }

    // 테두리(Outlined 전용). 활성은 Primary/Normal 43%, 그 외/비활성은 Line/Normal/Neutral.
    func border(isEnabled: Bool) -> (color: Color, width: CGFloat)? {
        guard variant == .outlined else { return nil }
        if isEnabled, isActive { return (activeAccent.opacity(0.43), 1) }
        return (.mhLineNormalNeutral, 1)
    }

    // press 오버레이 색(Figma Interaction 레이어): Solid 활성=Inverse/Label(밝게),
    // Outlined 활성=Primary/Normal(=activeAccent), 그 외=Label/Normal.
    var pressedOverlayColor: Color {
        guard isActive else { return .mhLabelNormal }
        return variant == .solid ? .mhInverseLabel : activeAccent
    }
}

struct MHChipMetric {
    let font: MHTypography
    let height: CGFloat        // Figma 고정 칩 높이
    let hPadding: CGFloat      // 칩 외곽 좌우 패딩(Figma px). 세로는 height 로 고정
    let textHPadding: CGFloat  // 텍스트 내부 Wrapper 좌우 패딩(Figma text Wrapper px). 텍스트에만 적용
    let cornerRadius: CGFloat
    let gap: CGFloat
    let iconSize: CGFloat      // leading/trailing 슬롯 정사각 크기
}

extension MHChipSize {
    // 폰트·높이·패딩·radius·gap·아이콘은 Figma get_design_context 실측값.
    // 높이(24/32/36/40)는 폰트 라인박스가 SUITE intrinsic 보다 커 '패딩+intrinsic' 로는 부족해 직접 고정한다(버튼과 동일 이유).
    // textHPadding: Figma 는 텍스트를 px-[2px](XSmall 은 1px) Wrapper 로 감싸므로 텍스트 폭에 그만큼 더해진다.
    var metric: MHChipMetric {
        switch self {
        case .xsmall: MHChipMetric(font: .caption1Medium,     height: 24, hPadding: 7,  textHPadding: 1, cornerRadius: 6,  gap: 2, iconSize: 12)
        case .small:  MHChipMetric(font: .label1NormalMedium, height: 32, hPadding: 8,  textHPadding: 2, cornerRadius: 8,  gap: 2, iconSize: 14)
        case .medium: MHChipMetric(font: .body2NormalMedium,  height: 36, hPadding: 11, textHPadding: 2, cornerRadius: 10, gap: 3, iconSize: 14)
        case .large:  MHChipMetric(font: .body2NormalMedium,  height: 40, hPadding: 12, textHPadding: 2, cornerRadius: 10, gap: 3, iconSize: 16)
        }
    }
}

// MARK: - ButtonStyle (배경·테두리·press 오버레이)

struct MHChipStyle: ButtonStyle {
    let spec: MHChipSpec
    let isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        MHChipStyleBody(spec: spec, isEnabled: isEnabled, configuration: configuration)
    }

    // Figma State=Pressed = Normal ×0.75(Interaction/Light). 실측 오버레이 opacity = 0.09.
    static let pressedOpacity: Double = 0.09
}

private struct MHChipStyleBody: View {
    let spec: MHChipSpec
    let isEnabled: Bool
    let configuration: ButtonStyle.Configuration

    var body: some View {
        let metric = spec.size.metric
        configuration.label
            .foregroundStyle(spec.foreground(isEnabled: isEnabled))
            .padding(.horizontal, metric.hPadding)
            .frame(height: metric.height)
            .background(spec.background(isEnabled: isEnabled))
            .overlay {
                if configuration.isPressed {
                    spec.pressedOverlayColor.opacity(MHChipStyle.pressedOpacity)
                }
            }
            .overlay {
                if let stroke = spec.border(isEnabled: isEnabled) {
                    RoundedRectangle(cornerRadius: metric.cornerRadius).strokeBorder(stroke.color, lineWidth: stroke.width)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: metric.cornerRadius))
    }
}

#Preview("MHChip") {
    VStack(alignment: .leading, spacing: 12) {
        HStack { MHChip("전체", isActive: true) {}; MHChip("최신순") {}; MHChip("인기") {} }
        HStack { MHChip("필터", variant: .outlined, leading: .icon(.tune)) {}; MHChip("삭제", size: .small, trailing: .icon(.close)) {} }
    }
    .padding()
}
