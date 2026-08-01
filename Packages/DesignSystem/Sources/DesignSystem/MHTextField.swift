import SwiftUI

// MARK: - TextField

/// 검증/상태 표현. `normal`(기본) / `positive`(성공) / `negative`(에러). Figma `status` 축.
///
/// `positive`·`negative` 는 trailing 에 상태 아이콘(체크/느낌표)을 자동으로 띄우고,
/// `negative` 는 테두리·description 색을 에러색으로 바꾼다.
public enum MHTextFieldStatus: Sendable { case normal, positive, negative }

/// trailing 버튼 강조 위계. `normal`(Bold·Primary/Normal) / `assistive`(Medium·Label/Normal). Figma `variant` 축.
public enum MHTextFieldButtonVariant: Sendable { case normal, assistive }

/// 입력 박스 오른쪽에 분절되어 붙는 텍스트 버튼(Figma `trailingButton`). 예: "확인"·"인증".
///
/// 필드 본체와 별개로 자기 활성 상태(`isEnabled`)를 갖는다(입력은 되지만 버튼만 비활성 등).
public struct MHTextFieldTrailingButton {
    let title: String
    let variant: MHTextFieldButtonVariant
    let isEnabled: Bool
    let leadingIcon: MHIcon?
    let trailingIcon: MHIcon?
    let action: () -> Void

    public init(
        _ title: String,
        variant: MHTextFieldButtonVariant = .normal,
        isEnabled: Bool = true,
        leadingIcon: MHIcon? = nil,
        trailingIcon: MHIcon? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.isEnabled = isEnabled
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.action = action
    }

    // 라벨 색: 비활성=Label/Assistive, normal=Primary/Normal(검정), assistive=Label/Normal (Figma variant 실측).
    var textColor: Color {
        guard isEnabled else { return .mhLabelAssistive }
        return variant == .normal ? .mhPrimaryNormal : .mhLabelNormal
    }
    // 타이포: normal=Body1 Bold, assistive=Body1 Medium (라벨이라 SUITE 사용 — 입력이 아님).
    var typography: MHTypography { variant == .normal ? .body1NormalBold : .body1NormalMedium }
    // 테두리: 활성=Line/Normal/Neutral, 비활성=Line/Normal/Alternative.
    var borderColor: Color { isEnabled ? .mhLineNormalNeutral : .mhLineNormalAlternative }
    // 비활성 배경만 Interaction/Disable(활성은 필드 배경 투과).
    var backgroundColor: Color { isEnabled ? .clear : .mhInteractionDisable }
}

/// 한 줄 텍스트 입력 필드. Figma `Textinput/Textfield`.
///
/// 세로로 **Heading(라벨) → Input 박스 → Description(도움말)** 이 쌓이며, Heading·Description·
/// leading 아이콘·required(*) 배지·clear(×) 버튼은 선택 슬롯이다. 상태(``MHTextFieldStatus``)와
/// 포커스(내부 `@FocusState`)·`.disabled(_:)` 에 따라 테두리·색이 바뀐다.
///
/// > 입력 텍스트는 **시스템 폰트**를 쓴다(SUITE 는 한글 조합 중 빈 글리프 이슈 — DesignSystem README 참조).
/// > 라벨·도움말 등 그 외 텍스트만 ``MHTypography``(SUITE)를 쓴다.
///
/// ```swift
/// MHTextField("텍스트를 입력해 주세요.", text: $name)                       // 기본
/// MHTextField("닉네임", text: $name, heading: "주제", isRequired: true)     // 라벨 + 필수(*)
/// MHTextField("검색", text: $q, leadingIcon: .search)                      // leading 아이콘
/// MHTextField("이메일", text: $email,
///             description: "에러 메시지를 나타내요.", status: .negative)     // 에러(빨간 테두리·도움말)
/// MHTextField("코드", text: $code, status: .positive)                     // 성공(체크 아이콘)
/// MHTextField("고정", text: $v).disabled(true)                            // 표준 .disabled
/// ```
public struct MHTextField: View {
    @Binding private var text: String
    private let placeholder: String
    private let heading: String?
    private let isRequired: Bool
    private let description: String?
    private let status: MHTextFieldStatus
    private let leadingIcon: MHIcon?
    private let showsClearButton: Bool
    private let trailingButton: MHTextFieldTrailingButton?
    private let trailingContent: AnyView?

    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool

    public init(
        _ placeholder: String = "",
        text: Binding<String>,
        heading: String? = nil,
        isRequired: Bool = false,
        description: String? = nil,
        status: MHTextFieldStatus = .normal,
        leadingIcon: MHIcon? = nil,
        showsClearButton: Bool = true,
        trailingButton: MHTextFieldTrailingButton? = nil,
        @ViewBuilder trailingContent: () -> some View = { EmptyView() }
    ) {
        self._text = text
        self.placeholder = placeholder
        self.heading = heading
        self.isRequired = isRequired
        self.description = description
        self.status = status
        self.leadingIcon = leadingIcon
        self.showsClearButton = showsClearButton
        self.trailingButton = trailingButton
        let content = trailingContent()
        self.trailingContent = content is EmptyView ? nil : AnyView(content)
    }

    public var body: some View {
        let spec = MHTextFieldSpec(status: status, isEnabled: isEnabled, isFocused: isFocused)
        VStack(alignment: .leading, spacing: MHTextFieldMetric.stackSpacing) {
            if let heading { headingRow(heading) }
            inputBox(spec)
            if let description {
                Text(description)
                    .mhTypography(.caption1Regular)
                    .foregroundStyle(spec.descriptionColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: Heading (라벨 + 필수 배지)

    @ViewBuilder private func headingRow(_ heading: String) -> some View {
        HStack(spacing: MHTextFieldMetric.headingGap) {
            Text(heading)
                .mhTypography(.label1NormalBold)
                .foregroundStyle(.mhLabelNeutral)
            if isRequired {
                Text("*")
                    .mhTypography(.label1NormalMedium)
                    .foregroundStyle(.mhStatusNegative)
            }
        }
    }

    // MARK: Input 박스

    // trailingButton 이 있으면 [입력부(좌측만 라운드) | 버튼(우측만 라운드)] 로 분절, 없으면 단일 라운드 박스.
    @ViewBuilder private func inputBox(_ spec: MHTextFieldSpec) -> some View {
        if let trailingButton {
            HStack(spacing: 0) {
                inputSegment(spec, corners: .left)
                    .frame(maxWidth: .infinity)
                trailingButtonSegment(trailingButton)
            }
            .mhShadow(.xsmall, cornerRadius: MHTextFieldMetric.cornerRadius)
        } else {
            inputSegment(spec, corners: .all)
                .mhShadow(.xsmall, cornerRadius: MHTextFieldMetric.cornerRadius)
        }
    }

    // 입력부 세그먼트: leading 아이콘·텍스트·trailing(clear/상태 아이콘) + 배경·테두리.
    @ViewBuilder private func inputSegment(_ spec: MHTextFieldSpec, corners: MHTextFieldCorners) -> some View {
        let shape = MHTextFieldMetric.shape(corners)
        HStack(spacing: MHTextFieldMetric.contentGap) {
            if let leadingIcon {
                Image(leadingIcon)
                    .resizable()
                    .frame(width: MHTextFieldMetric.iconSize, height: MHTextFieldMetric.iconSize)
                    .foregroundStyle(spec.leadingIconColor)
            }
            textField(spec)
                .padding(.horizontal, MHTextFieldMetric.textHPadding)
            trailingAccessory(spec)
            if let trailingContent {
                // 임의 커스텀 뷰 슬롯(단위 라벨·작은 컨트롤 등). 24pt 높이·hug 폭·overflow clip (Figma Trailing Content).
                trailingContent
                    .frame(height: MHTextFieldMetric.trailingContentHeight)
                    .clipped()
            }
        }
        .frame(minHeight: MHTextFieldMetric.contentMinHeight)
        .padding(MHTextFieldMetric.contentPadding)
        .frame(minHeight: MHTextFieldMetric.boxHeight)
        .background(spec.backgroundColor, in: shape)
        .overlay { shape.strokeBorder(spec.borderColor, lineWidth: spec.borderWidth) }
    }

    // trailing 버튼 세그먼트: 우측만 라운드, 라벨은 SUITE(입력 아님). variant/disable 로 굵기·색이 갈린다.
    // leading/trailing 아이콘(20pt)과 pressed 오버레이는 MHTextFieldButtonStyle 이 그린다.
    @ViewBuilder private func trailingButtonSegment(_ button: MHTextFieldTrailingButton) -> some View {
        Button(action: button.action) {
            HStack(spacing: MHTextFieldMetric.buttonIconGap) {
                if let icon = button.leadingIcon { buttonIcon(icon, color: button.textColor) }
                Text(button.title)
                    .mhTypography(button.typography)
                    .foregroundStyle(button.textColor)
                if let icon = button.trailingIcon { buttonIcon(icon, color: button.textColor) }
            }
        }
        .buttonStyle(MHTextFieldButtonStyle(button: button))
        .disabled(!button.isEnabled)
    }

    private func buttonIcon(_ icon: MHIcon, color: Color) -> some View {
        Image(icon).resizable()
            .frame(width: MHTextFieldMetric.buttonIconSize, height: MHTextFieldMetric.buttonIconSize)
            .foregroundStyle(color)
    }

    // 입력 텍스트: 시스템 폰트(SUITE 미적용). placeholder 는 빈 값일 때만 겹쳐 그린다(색 정밀 제어).
    // 색은 활성/비활성으로 갈린다(Figma disabled 행 실측): 값=Normal→Alternative, placeholder=Assistive→Disable.
    @ViewBuilder private func textField(_ spec: MHTextFieldSpec) -> some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(spec.placeholderColor)
            }
            TextField("", text: $text)
                .focused($isFocused)
                .foregroundStyle(spec.valueTextColor)
        }
        .font(.system(size: MHTextFieldMetric.inputFontSize))
        .lineLimit(1)
    }

    // trailing: 포커스+입력값이 있으면 clear(×), 아니면 상태 아이콘(positive=체크 / negative=느낌표 / normal=없음).
    // 같은 슬롯을 공유하며 clear 가 상태 아이콘을 대체한다 — Figma status 매트릭스(포커스 행=clear, 그 외=상태 아이콘) 실측.
    @ViewBuilder private func trailingAccessory(_ spec: MHTextFieldSpec) -> some View {
        switch spec.trailing(hasText: !text.isEmpty, showsClearButton: showsClearButton) {
        case .clear:
            Button {
                text = ""
            } label: {
                Image(MHIcon.circleClose)
                    .resizable()
                    .frame(width: MHTextFieldMetric.iconSize, height: MHTextFieldMetric.iconSize)
                    .foregroundStyle(.mhLabelAssistive)
            }
            .buttonStyle(.plain)
        case .positiveIcon:
            statusIcon(.circleCheckFill, color: .mhPrimaryNormal)
        case .negativeIcon:
            statusIcon(.circleExclamationFill, color: .mhStatusNegative)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder private func statusIcon(_ icon: MHIcon, color: Color) -> some View {
        Image(icon)
            .resizable()
            .frame(width: MHTextFieldMetric.iconSize, height: MHTextFieldMetric.iconSize)
            .foregroundStyle(color)
    }
}

// MARK: - Spec (상태 → Figma 토큰)

struct MHTextFieldSpec {
    let status: MHTextFieldStatus
    let isEnabled: Bool
    let isFocused: Bool

    // 배경: 활성=Background/Transparent/Normal, 비활성=Interaction/Disable.
    // (Figma 는 Transparent 위에 iOS Chrome 머티리얼 블러를 얹지만, 불투명 화면에선 안 보이고
    //  per-field backdrop 블러는 비용이 커 MHButton 과 같은 이유로 플랫 채움만 쓴다.)
    var backgroundColor: Color { isEnabled ? .mhBackgroundTransparentNormal : .mhInteractionDisable }

    // 테두리 색(Figma status 매트릭스 실측): 비활성 > 에러 > 포커스 > 기본.
    // 포커스는 색은 그대로 두고 불투명도만 43% 로 올린다(에러는 빨강 유지, 그 외는 Primary/Normal).
    // - 기본(unfocused): 일반/성공=Line/Normal/Neutral, 에러=Status/Negative 28%
    // - 포커스(focused):  일반/성공=Primary/Normal 43%, 에러=Status/Negative 43%
    var borderColor: Color {
        if !isEnabled { return .mhLineNormalAlternative }
        if status == .negative { return .mhStatusNegative.opacity(isFocused ? 0.43 : 0.28) }
        if isFocused { return .mhPrimaryNormal.opacity(0.43) }
        return .mhLineNormalNeutral
    }

    // 포커스면 2px(상태 무관 — 에러 포커스도 2px), 그 외 1px.
    var borderWidth: CGFloat {
        (isEnabled && isFocused) ? 2 : 1
    }

    // description(도움말) 색: 에러만 빨강, 그 외는 Label/Alternative(성공도 회색 유지 — Figma 실측).
    var descriptionColor: Color {
        status == .negative ? .mhStatusNegative : .mhLabelAlternative
    }

    // 입력 값(비어있지 않을 때) 텍스트 색: 활성=Label/Normal, 비활성=Label/Alternative (Figma disabled 행 실측).
    var valueTextColor: Color { isEnabled ? .mhLabelNormal : .mhLabelAlternative }

    // placeholder(빈 값) 색: 활성=Label/Assistive, 비활성=Label/Disable (Figma disabled 행 실측).
    var placeholderColor: Color { isEnabled ? .mhLabelAssistive : .mhLabelDisable }

    // leading 아이콘 색: Figma 스펙은 !Blank 플레이스홀더라 색이 정의되지 않아, 보조 라벨색으로 둔다.
    var leadingIconColor: Color { isEnabled ? .mhLabelAlternative : .mhLabelDisable }

    // trailing 슬롯 결정(Figma status 매트릭스 실측): 포커스+입력값이 있으면 clear(×), 아니면 상태 아이콘.
    // clear 는 상태 아이콘과 같은 슬롯을 대체한다(성공·에러 필드도 편집 중엔 clear 를 보여줌).
    func trailing(hasText: Bool, showsClearButton: Bool) -> MHTextFieldTrailing {
        if isEnabled, isFocused, showsClearButton, hasText { return .clear }
        switch status {
        case .positive: return .positiveIcon
        case .negative: return .negativeIcon
        case .normal:   return .none
        }
    }
}

/// Input trailing 슬롯에 무엇을 그릴지. clear(×) 버튼 또는 상태 아이콘(성공/에러) 또는 없음.
enum MHTextFieldTrailing: Equatable { case none, clear, positiveIcon, negativeIcon }

/// 세그먼트 라운드 위치. `all`=단독 박스, `left`=입력부(좌측만), `right`=trailing 버튼(우측만).
enum MHTextFieldCorners { case all, left, right }

// MARK: - Metric (Figma 실측 고정값)

enum MHTextFieldMetric {
    static let stackSpacing: CGFloat = 8      // Heading·Input·Description 세로 간격
    static let headingGap: CGFloat = 4        // 라벨 ↔ 필수(*) 간격
    static let contentGap: CGFloat = 8        // 아이콘 ↔ 텍스트 ↔ trailing 간격
    static let textHPadding: CGFloat = 4      // 텍스트 좌우 내부 패딩(Figma Text Wrapper px)
    static let contentPadding: CGFloat = 12   // Input 박스 내부 패딩
    static let contentMinHeight: CGFloat = 24 // 콘텐츠 최소 높이(Figma min-h)
    static let boxHeight: CGFloat = 48         // Input 박스 고정 높이(24 + 12*2)
    static let cornerRadius: CGFloat = 12
    static let iconSize: CGFloat = 22          // leading·상태·clear 아이콘 정사각
    static let trailingContentHeight: CGFloat = 24  // 커스텀 trailing content 슬롯 높이(Figma h)
    static let inputFontSize: CGFloat = 16     // 입력 텍스트(시스템 폰트)
    static let buttonMinWidth: CGFloat = 80    // trailing 버튼 최소 폭(Figma min-w)
    static let buttonHPadding: CGFloat = 16    // trailing 버튼 좌우 패딩(Figma px)
    static let buttonIconGap: CGFloat = 6      // 버튼 아이콘 ↔ 텍스트 간격(Figma gap)
    static let buttonIconSize: CGFloat = 20    // 버튼 leading/trailing 아이콘 정사각(Figma h)
    static let buttonPressedOpacity: Double = 0.09  // pressed 오버레이(Label/Normal, Figma interaction 실측)

    // 세그먼트별 라운드 모양(입력부=좌측만, 버튼=우측만, 단독=사방).
    static func shape(_ corners: MHTextFieldCorners) -> UnevenRoundedRectangle {
        let r = cornerRadius
        switch corners {
        case .all:   return UnevenRoundedRectangle(topLeadingRadius: r, bottomLeadingRadius: r, bottomTrailingRadius: r, topTrailingRadius: r)
        case .left:  return UnevenRoundedRectangle(topLeadingRadius: r, bottomLeadingRadius: r, bottomTrailingRadius: 0, topTrailingRadius: 0)
        case .right: return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0, bottomTrailingRadius: r, topTrailingRadius: r)
        }
    }
}

// MARK: - Trailing 버튼 ButtonStyle (배경·테두리·pressed 오버레이)

// 우측 라운드 세그먼트로 라벨을 감싸고, pressed 시 Label/Normal 오버레이를 얹는다(Figma interaction 실측).
struct MHTextFieldButtonStyle: ButtonStyle {
    let button: MHTextFieldTrailingButton

    func makeBody(configuration: Configuration) -> some View {
        let shape = MHTextFieldMetric.shape(.right)
        configuration.label
            .padding(.horizontal, MHTextFieldMetric.buttonHPadding)
            .frame(minWidth: MHTextFieldMetric.buttonMinWidth, minHeight: MHTextFieldMetric.boxHeight)
            .background(button.backgroundColor, in: shape)
            .overlay {
                if configuration.isPressed {
                    shape.fill(Color.mhLabelNormal.opacity(MHTextFieldMetric.buttonPressedOpacity))
                }
            }
            .overlay { shape.strokeBorder(button.borderColor, lineWidth: 1) }
            .contentShape(shape)
    }
}
