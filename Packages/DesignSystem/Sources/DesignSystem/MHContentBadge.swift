import SwiftUI

// MARK: - Content Badge

/// 배경·테두리 스타일. `solid`(옅은 배경 채움) / `outlined`(테두리만). Figma `variant`.
public enum MHContentBadgeVariant: Sendable { case solid, outlined }
/// 크기 프리셋. 폰트·패딩·radius·아이콘이 함께 정해진다. Figma `size`.
public enum MHContentBadgeSize: Sendable { case xsmall, small, medium }

/// 정보를 항목별로 분류·강조하는 낮은 위계의 라벨. Figma `Content Badge`.
///
/// ``MHContentBadgeVariant``(Solid/Outlined) × ``MHContentBadgeSize``(XS/S/M) 축에 leading/trailing
/// 아이콘과 색을 조합한다. 색은 기본 **Neutral**(회색 시맨틱 토큰)이며, `color` 에 강조색을 주면
/// **Accent** 로 바뀐다(글자=그 색, Solid 배경=그 색 8%, Outlined 테두리=그 색 43%). 상호작용 없는 표시용.
///
/// ```swift
/// MHContentBadge("신규")                                        // solid · small · neutral
/// MHContentBadge("BETA", variant: .outlined, size: .medium)
/// MHContentBadge("추천", color: .mhAccentForegroundCyan)         // accent(강조색)
/// MHContentBadge("인기", leadingIcon: .star)                     // 아이콘
/// ```
public struct MHContentBadge: View {
    private let text: String
    private let variant: MHContentBadgeVariant
    private let size: MHContentBadgeSize
    private let color: Color?
    private let leadingIcon: MHIcon?
    private let trailingIcon: MHIcon?

    public init(
        _ text: String,
        variant: MHContentBadgeVariant = .solid,
        size: MHContentBadgeSize = .small,
        color: Color? = nil,
        leadingIcon: MHIcon? = nil,
        trailingIcon: MHIcon? = nil
    ) {
        self.text = text
        self.variant = variant
        self.size = size
        self.color = color
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
    }

    public var body: some View {
        let metric = size.metric
        let spec = MHContentBadgeSpec(variant: variant, color: color)
        let shape = RoundedRectangle(cornerRadius: metric.cornerRadius)
        HStack(spacing: metric.gap) {
            if let leadingIcon { icon(leadingIcon, spec.contentColor, metric.iconSize) }
            Text(text)
                .mhTypography(metric.font)
                .foregroundStyle(spec.contentColor)
            if let trailingIcon { icon(trailingIcon, spec.contentColor, metric.iconSize) }
        }
        .padding(.horizontal, metric.hPadding)
        .frame(height: metric.height)                       // Figma 고정 높이(SUITE intrinsic < 라인박스 — 버튼/칩과 동일 이유)
        .background(spec.fillColor)
        .overlay {
            if let border = spec.borderColor {
                shape.strokeBorder(border, lineWidth: 1)
            }
        }
        .clipShape(shape)
    }

    private func icon(_ icon: MHIcon, _ color: Color, _ size: CGFloat) -> some View {
        Image(icon).resizable().frame(width: size, height: size).foregroundStyle(color)
    }
}

// MARK: - Spec (Neutral/Accent × Solid/Outlined → 색)

struct MHContentBadgeSpec {
    let variant: MHContentBadgeVariant
    let color: Color?   // nil = Neutral(시맨틱 토큰), non-nil = Accent(그 색)

    // 글자·아이콘 색: Accent=그 색, Neutral=Label/Alternative.
    var contentColor: Color { color ?? .mhLabelAlternative }

    // Solid 배경 채움(Outlined 는 clear): Accent=그 색 8%, Neutral=Fill/Normal.
    var fillColor: Color {
        guard variant == .solid else { return .clear }
        return color?.opacity(0.08) ?? .mhFillNormal
    }

    // Outlined 테두리(Solid 는 없음): Accent=그 색 43%, Neutral=Line/Normal/Neutral.
    var borderColor: Color? {
        guard variant == .outlined else { return nil }
        return color?.opacity(0.43) ?? .mhLineNormalNeutral
    }
}

// MARK: - Metric (Figma 실측)

struct MHContentBadgeMetric {
    let font: MHTypography
    let height: CGFloat        // Figma 고정 높이
    let hPadding: CGFloat      // 좌우 패딩(세로는 height 로 고정)
    let cornerRadius: CGFloat
    let gap: CGFloat           // 아이콘 ↔ 텍스트 간격
    let iconSize: CGFloat      // leading/trailing 아이콘 정사각
}

extension MHContentBadgeSize {
    var metric: MHContentBadgeMetric {
        switch self {
        case .xsmall: MHContentBadgeMetric(font: .caption2Medium, height: 20, hPadding: 6, cornerRadius: 6, gap: 2, iconSize: 12)
        case .small:  MHContentBadgeMetric(font: .caption1Medium, height: 24, hPadding: 6, cornerRadius: 6, gap: 3, iconSize: 14)
        case .medium: MHContentBadgeMetric(font: .label2Medium,   height: 28, hPadding: 8, cornerRadius: 8, gap: 4, iconSize: 16)
        }
    }
}

#Preview("MHContentBadge") {
    VStack(spacing: 12) {
        HStack { MHContentBadge("N"); MHContentBadge("NEW", variant: .outlined); MHContentBadge("3", size: .xsmall) }
        HStack { MHContentBadge("완료", color: .mhStatusPositive); MHContentBadge("주의", color: .mhStatusNegative, leadingIcon: .circleExclamation) }
    }
    .padding()
}
