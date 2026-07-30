import SwiftUI

// MARK: - TextField

/// 검증/상태 표현. `normal`(기본) / `positive`(성공) / `negative`(에러). Figma `status` 축.
///
/// `positive`·`negative` 는 trailing 에 상태 아이콘(체크/느낌표)을 자동으로 띄우고,
/// `negative` 는 테두리·description 색을 에러색으로 바꾼다.
public enum MHTextFieldStatus: Sendable { case normal, positive, negative }

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
        showsClearButton: Bool = true
    ) {
        self._text = text
        self.placeholder = placeholder
        self.heading = heading
        self.isRequired = isRequired
        self.description = description
        self.status = status
        self.leadingIcon = leadingIcon
        self.showsClearButton = showsClearButton
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

    @ViewBuilder private func inputBox(_ spec: MHTextFieldSpec) -> some View {
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
        }
        .frame(minHeight: MHTextFieldMetric.contentMinHeight)
        .padding(MHTextFieldMetric.contentPadding)
        .frame(minHeight: MHTextFieldMetric.boxHeight)
        .background(spec.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: MHTextFieldMetric.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: MHTextFieldMetric.cornerRadius)
                .strokeBorder(spec.borderColor, lineWidth: spec.borderWidth)
        }
        .mhShadow(.xsmall, cornerRadius: MHTextFieldMetric.cornerRadius)
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
    static let inputFontSize: CGFloat = 16     // 입력 텍스트(시스템 폰트)
}
