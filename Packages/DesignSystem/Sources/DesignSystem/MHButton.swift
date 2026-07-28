import SwiftUI

// MARK: - Button
//
// Figma `Button/Button`. 가장 높은 시각 위계를 갖는 CTA 버튼이다.
// 축: variant(Solid/Outlined) × color(Primary/Assistive) × size(S/M/L) + iconOnly + disable + loading.
//
//     MHButton("메인 액션") { ... }                                   // 기본: solid·primary·large
//     MHButton("보조", variant: .outlined, color: .assistive, size: .medium) { ... }
//     MHButton("담기", leadingIcon: .plus) { ... }                    // 아이콘 + 텍스트
//     MHButton(icon: .setting, size: .large) { ... }                  // 아이콘 전용(정사각)
//     MHButton("전송", isLoading: vm.isSending) { ... }               // 로딩(라벨 숨기고 스피너)
//     MHButton("확인") { ... }.disabled(true)                          // 표준 .disabled 사용
//
// 색·타이포는 전부 시맨틱 토큰(SemanticColors)·MHTypography 를 참조한다.
// color 축은 사실상 **글자 굵기**(Primary=Bold, Assistive=Medium)와 Solid 의 bg/text 를 가른다.

public enum MHButtonVariant: Sendable { case solid, outlined }
public enum MHButtonColor: Sendable { case primary, assistive }
public enum MHButtonSize: Sendable { case small, medium, large }

public struct MHButton: View {
    private let title: String?
    private let icon: MHIcon?            // 아이콘 전용(정사각)일 때
    private let leadingIcon: MHIcon?
    private let trailingIcon: MHIcon?
    private let variant: MHButtonVariant
    private let color: MHButtonColor
    private let size: MHButtonSize
    private let isLoading: Bool
    private let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    /// 텍스트(+선택 아이콘) 버튼
    public init(
        _ title: String,
        variant: MHButtonVariant = .solid,
        color: MHButtonColor = .primary,
        size: MHButtonSize = .large,
        leadingIcon: MHIcon? = nil,
        trailingIcon: MHIcon? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = nil
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.variant = variant
        self.color = color
        self.size = size
        self.isLoading = isLoading
        self.action = action
    }

    /// 아이콘 전용(정사각) 버튼
    public init(
        icon: MHIcon,
        variant: MHButtonVariant = .solid,
        color: MHButtonColor = .primary,
        size: MHButtonSize = .large,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = nil
        self.icon = icon
        self.leadingIcon = nil
        self.trailingIcon = nil
        self.variant = variant
        self.color = color
        self.size = size
        self.isLoading = isLoading
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(
            MHButtonStyle(
                spec: MHButtonSpec(variant: variant, color: color, size: size),
                isEnabled: isEnabled,
                isLoading: isLoading,
                isIconOnly: icon != nil
            )
        )
        .disabled(isLoading)          // 로딩 중엔 탭 차단
        .allowsHitTesting(!isLoading)
    }

    @ViewBuilder private var content: some View {
        let metric = size.metric
        ZStack {
            // 로딩 스피너: 라벨을 가리고 중앙에 표시
            if isLoading {
                MHButtonSpinner(size: metric.iconSize)
            }
            HStack(spacing: metric.gap) {
                if let icon { Image(icon).resizable().frame(width: metric.iconSize, height: metric.iconSize) }
                if let leadingIcon { Image(leadingIcon).resizable().frame(width: metric.iconSize, height: metric.iconSize) }
                if let title {
                    Text(title).mhTypography(size.typography(for: color))
                }
                if let trailingIcon { Image(trailingIcon).resizable().frame(width: metric.iconSize, height: metric.iconSize) }
            }
            .opacity(isLoading ? 0 : 1)
        }
    }
}

// MARK: - Spec (Figma 토큰 매핑)

struct MHButtonSpec {
    let variant: MHButtonVariant
    let color: MHButtonColor
    let size: MHButtonSize

    /// 배경색
    var background: Color {
        switch (variant, color) {
        case (.solid, .primary):    .mhPrimaryNormal      // Primary/Normal #000
        case (.solid, .assistive):  .mhFillNormal         // Fill/Normal (반투명 회색)
        case (.outlined, _):        .clear
        }
    }

    /// 전경(글자·아이콘)색
    var foreground: Color {
        switch (variant, color) {
        case (.solid, .primary):    .mhStaticWhite        // Static/White
        case (.solid, .assistive):  .mhLabelNeutral       // Label/Neutral
        case (.outlined, _):        .mhLabelNormal        // Label/Normal
        }
    }

    /// 테두리색(Outlined 만)
    var border: Color? {
        variant == .outlined ? .mhLineNormalNeutral : nil // Line/Normal/Neutral
    }

    // 비활성(disable) — Figma: bg Interaction/Disable, text Label/Assistive
    var disabledBackground: Color { variant == .solid ? .mhInteractionDisable : .clear }
    var disabledForeground: Color { .mhLabelAssistive }
    var disabledBorder: Color? { variant == .outlined ? .mhLineNormalNeutral : nil }
}

struct MHButtonMetric {
    let hPadding: CGFloat
    let vPadding: CGFloat
    let cornerRadius: CGFloat
    let gap: CGFloat
    let iconSize: CGFloat
}

extension MHButtonSize {
    // 패딩·radius·gap 은 Figma get_design_context 실측값.
    var metric: MHButtonMetric {
        switch self {
        case .large:  MHButtonMetric(hPadding: 28, vPadding: 12, cornerRadius: 12, gap: 6, iconSize: 20)
        case .medium: MHButtonMetric(hPadding: 20, vPadding: 9,  cornerRadius: 10, gap: 5, iconSize: 18)
        case .small:  MHButtonMetric(hPadding: 14, vPadding: 7,  cornerRadius: 8,  gap: 4, iconSize: 16)
        }
    }

    // Primary=Bold, Assistive=Medium. (Small=Label2 는 Medium 이 없어 Regular 로 대체)
    func typography(for color: MHButtonColor) -> MHTypography {
        switch (self, color) {
        case (.large, .primary):    .body1NormalBold
        case (.large, .assistive):  .body1NormalMedium
        case (.medium, .primary):   .body2NormalBold
        case (.medium, .assistive): .body2NormalMedium
        case (.small, .primary):    .label2Bold
        case (.small, .assistive):  .label2Regular
        }
    }
}

// MARK: - ButtonStyle (배경·테두리·press 오버레이)

struct MHButtonStyle: ButtonStyle {
    let spec: MHButtonSpec
    let isEnabled: Bool
    let isLoading: Bool
    let isIconOnly: Bool

    func makeBody(configuration: Configuration) -> some View {
        let metric = spec.size.metric
        let bg = isEnabled ? spec.background : spec.disabledBackground
        let fg = isEnabled ? spec.foreground : spec.disabledForeground
        let stroke = isEnabled ? spec.border : spec.disabledBorder

        return configuration.label
            .foregroundStyle(fg)
            .padding(.horizontal, isIconOnly ? metric.vPadding : metric.hPadding) // 아이콘 전용은 정사각
            .padding(.vertical, metric.vPadding)
            .background(bg)
            .overlay {
                // press 인터랙션 오버레이(Figma: 최상단 Interaction 레이어). 밝은 배경은 어둡게, 어두운 solid 는 밝게.
                if configuration.isPressed {
                    pressedOverlayColor.opacity(Self.pressedOpacity)
                }
            }
            .overlay {
                if let stroke {
                    RoundedRectangle(cornerRadius: metric.cornerRadius).strokeBorder(stroke, lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: metric.cornerRadius))
    }

    // NOTE(스펙 확인 필요): Figma 인터랙션 오버레이는 Label/Normal opacity 0(rest)이고 상태별 값이 미확정.
    // 어두운 solid/primary 는 어두운 오버레이가 안 보여, 대비를 위해 밝은 오버레이로 스왑한다(디자인 노트: 색 교체 허용).
    private var pressedOverlayColor: Color {
        (spec.variant == .solid && spec.color == .primary) ? .mhStaticWhite : .mhLabelNormal
    }
    static let pressedOpacity: Double = 0.12
}

// MARK: - Spinner (loading)

struct MHButtonSpinner: View {
    let size: CGFloat
    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(style: StrokeStyle(lineWidth: max(1.5, size / 10), lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: spin)
            .onAppear { spin = true }
    }
}
