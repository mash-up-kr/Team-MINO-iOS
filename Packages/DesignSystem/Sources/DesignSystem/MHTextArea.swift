import SwiftUI

// MARK: - TextArea

/// 검증 상태. `normal`(기본) / `negative`(에러). Figma `status` 축 (TextArea 는 positive 없음).
public enum MHTextAreaStatus: Sendable { case normal, negative }

/// 높이 동작(Figma `resize` 축). 한 줄 = 26pt.
/// - `normal`: `minLines` 부터 내용에 맞춰 무한 성장
/// - `limit`: `minLines`~`maxLines` 성장 후 고정(초과분 clip)
/// - `fixed`: `lines` 고정
public enum MHTextAreaResize: Equatable, Sendable {
    case normal(minLines: Int = 3)
    case limit(minLines: Int = 3, maxLines: Int)
    case fixed(lines: Int)

    var minHeight: CGFloat {
        switch self {
        case .normal(let m):        return CGFloat(m) * MHTextAreaMetric.lineHeight
        case .limit(let m, _):      return CGFloat(m) * MHTextAreaMetric.lineHeight
        case .fixed(let l):         return CGFloat(l) * MHTextAreaMetric.lineHeight
        }
    }
    var maxHeight: CGFloat? {
        switch self {
        case .normal:               return nil                                   // 무한 성장
        case .limit(_, let mx):     return CGFloat(mx) * MHTextAreaMetric.lineHeight
        case .fixed(let l):         return CGFloat(l) * MHTextAreaMetric.lineHeight
        }
    }
}

/// 내용이 많은 여러 줄 텍스트 입력. Figma `Textinput/Textarea`.
///
/// 세로로 **Heading → 입력 박스(여러 줄 + 하단 바) → Description** 이 쌓인다. 하단 바(bottom)의
/// leading/trailing 슬롯에는 ``MHCharacterCounter``·``MHTextButton``·아이콘·``MHChip`` 등 무엇이든 넣는다.
/// 상태(``MHTextAreaStatus``)·포커스·`.disabled(_:)`·``MHTextAreaResize`` 에 따라 테두리·높이가 바뀐다.
///
/// > 입력 텍스트는 **시스템 폰트**를 쓴다(SUITE 는 한글 조합 중 빈 글리프 이슈 — README). 라벨·카운터·버튼만 SUITE.
///
/// ```swift
/// MHTextArea("메시지를 입력해 주세요.", text: $memo, heading: "주제",
///            description: "메시지에 마침표를 찍어요.",
///            bottomLeading: { MHCharacterCounter(count: memo.count, limit: 2000) },
///            bottomTrailing: { MHTextButton("전송") { send() } })
/// ```
public struct MHTextArea<Leading: View, Trailing: View>: View {
    @Binding private var text: String
    private let placeholder: String
    private let heading: String?
    private let isRequired: Bool
    private let description: String?
    private let status: MHTextAreaStatus
    private let resize: MHTextAreaResize
    private let bottomLeading: Leading
    private let bottomTrailing: Trailing

    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool

    public init(
        _ placeholder: String = "",
        text: Binding<String>,
        heading: String? = nil,
        isRequired: Bool = false,
        description: String? = nil,
        status: MHTextAreaStatus = .normal,
        resize: MHTextAreaResize = .normal(),
        @ViewBuilder bottomLeading: () -> Leading = { EmptyView() },
        @ViewBuilder bottomTrailing: () -> Trailing = { EmptyView() }
    ) {
        self._text = text
        self.placeholder = placeholder
        self.heading = heading
        self.isRequired = isRequired
        self.description = description
        self.status = status
        self.resize = resize
        self.bottomLeading = bottomLeading()
        self.bottomTrailing = bottomTrailing()
    }

    private var hasBottom: Bool { !(bottomLeading is EmptyView) || !(bottomTrailing is EmptyView) }

    public var body: some View {
        let spec = MHTextAreaSpec(status: status, isEnabled: isEnabled, isFocused: isFocused)
        VStack(alignment: .leading, spacing: MHTextAreaMetric.stackSpacing) {
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

    // MARK: Heading

    @ViewBuilder private func headingRow(_ heading: String) -> some View {
        HStack(spacing: MHTextAreaMetric.headingGap) {
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

    @ViewBuilder private func inputBox(_ spec: MHTextAreaSpec) -> some View {
        let shape = RoundedRectangle(cornerRadius: MHTextAreaMetric.cornerRadius)
        VStack(spacing: MHTextAreaMetric.contentGap) {
            textInput(spec)
                .frame(minHeight: resize.minHeight, maxHeight: resize.maxHeight ?? .infinity, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
            if hasBottom { bottomBar }
        }
        .padding(MHTextAreaMetric.contentPadding)
        .background(spec.backgroundColor, in: shape)
        .overlay { shape.strokeBorder(spec.borderColor, lineWidth: spec.borderWidth) }
        .clipShape(shape)                                   // Figma overflow-clip
        .mhShadow(.xsmall, cornerRadius: MHTextAreaMetric.cornerRadius)
    }

    // 여러 줄 입력: 시스템 폰트(SUITE 미적용). placeholder 는 빈 값일 때 겹쳐 그린다.
    @ViewBuilder private func textInput(_ spec: MHTextAreaSpec) -> some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(spec.placeholderColor)
                    .padding(.horizontal, MHTextAreaMetric.textHPadding)
            }
            TextField("", text: $text, axis: .vertical)
                .focused($isFocused)
                .foregroundStyle(spec.valueTextColor)
                .padding(.horizontal, MHTextAreaMetric.textHPadding)
        }
        .font(.system(size: MHTextAreaMetric.inputFontSize))
        .lineSpacing(MHTextAreaMetric.lineSpacing)
    }

    // MARK: 하단 바 (leading 은 좌측 확장, trailing 은 우측 hug)
    @ViewBuilder private var bottomBar: some View {
        HStack(spacing: MHTextAreaMetric.bottomGap) {
            HStack(spacing: MHTextAreaMetric.bottomItemGap) { bottomLeading }
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: MHTextAreaMetric.bottomItemGap) { bottomTrailing }
        }
    }
}

// MARK: - Spec (상태 → Figma 토큰, TextField 와 동일 규칙)

struct MHTextAreaSpec {
    let status: MHTextAreaStatus
    let isEnabled: Bool
    let isFocused: Bool

    var backgroundColor: Color { isEnabled ? .mhBackgroundTransparentNormal : .mhInteractionDisable }

    // 비활성 > 에러 > 포커스 > 기본. 포커스는 불투명도 43%·2px(에러는 빨강 유지).
    var borderColor: Color {
        if !isEnabled { return .mhLineNormalAlternative }
        if status == .negative { return .mhStatusNegative.opacity(isFocused ? 0.43 : 0.28) }
        if isFocused { return .mhPrimaryNormal.opacity(0.43) }
        return .mhLineNormalNeutral
    }
    var borderWidth: CGFloat { (isEnabled && isFocused) ? 2 : 1 }

    var descriptionColor: Color { status == .negative ? .mhStatusNegative : .mhLabelAlternative }
    var valueTextColor: Color { isEnabled ? .mhLabelNormal : .mhLabelAlternative }
    var placeholderColor: Color { isEnabled ? .mhLabelAssistive : .mhLabelDisable }
}

// MARK: - Metric (Figma 실측)

enum MHTextAreaMetric {
    static let stackSpacing: CGFloat = 8      // Heading·Box·Description 세로 간격
    static let headingGap: CGFloat = 4
    static let contentGap: CGFloat = 12       // 텍스트 ↔ 하단 바 간격
    static let contentPadding: CGFloat = 12   // 박스 내부 패딩
    static let cornerRadius: CGFloat = 12
    static let textHPadding: CGFloat = 4      // 텍스트 좌우 내부 패딩(Figma px-4)
    static let inputFontSize: CGFloat = 16    // 입력 텍스트(시스템 폰트)
    static let lineHeight: CGFloat = 26       // 한 줄 높이(Figma 개발코멘트: 26px)
    static let lineSpacing: CGFloat = 6       // 시스템폰트 16 기본 라인높이 + 이 값 ≈ 26
    static let bottomGap: CGFloat = 16        // leading ↔ trailing 간격
    static let bottomItemGap: CGFloat = 4     // 같은 쪽 아이템 간격
}
