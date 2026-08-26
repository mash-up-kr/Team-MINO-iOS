import SwiftUI

/// 검증 상태. `normal`(기본) / `negative`(에러). Figma `status` 축 (TextArea 는 positive 없음).
public enum MHTextAreaStatus: Sendable { case normal, negative }

/// 높이 동작(Figma `resize` 축). 한 줄 = 26pt.
/// - `normal`: `minLines` 부터 내용에 맞춰 무한 성장
/// - `limit`: `minLines`~`maxLines` 성장 후 고정(초과분 clip)
/// - `fixed`: `lines` 고정
public enum MHTextAreaResize: Equatable, Sendable {
    case normal(minLines: Int = 1)
    case limit(minLines: Int = 1, maxLines: Int)
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
    /// 입력 요소(내부 `TextField`)의 접근성 식별자. QA 자동화가 화면 안에서 필드를 특정하는 데 쓴다.
    private let identifier: String?

    @Environment(\.isEnabled) private var isEnabled
    @FocusState private var isFocused: Bool
    @State private var measuredTextHeight: CGFloat = MHTextAreaMetric.lineHeight

    public init(
        _ placeholder: String = "",
        text: Binding<String>,
        heading: String? = nil,
        isRequired: Bool = false,
        description: String? = nil,
        status: MHTextAreaStatus = .normal,
        resize: MHTextAreaResize = .normal(),
        identifier: String? = nil,
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
        self.identifier = identifier
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
            if hasBottom { bottomBar }
        }
        .padding(MHTextAreaMetric.contentPadding)
        .background {
            // 불투명 base + 프로스트 틴트. base 가 없으면 아래 mhShadow(.xsmall) 의 그림자 잉크가
            // 반투명(8% 흰색) 프로스트를 통과해 박스 내부를 회색(#EAEAEA)으로 채운다.
            // Figma 는 그림자를 항상 불투명 표면(Background/Normal/Normal)과 함께 쓴다 — Shadow 토큰 레퍼런스 확인.
            shape.fill(Color.mhBackgroundNormalNormal)
            shape.fill(spec.backgroundColor)               // Background/Transparent/Normal(enabled) / Interaction/Disable(disabled)
        }
        .overlay { shape.strokeBorder(spec.borderColor, lineWidth: spec.borderWidth) }
        .clipShape(shape)                                   // Figma overflow-clip
        .mhShadow(.xsmall, cornerRadius: MHTextAreaMetric.cornerRadius)
    }

    // 텍스트 영역 높이: 내용 높이를 min~max(resize)로 클램프. 내용이 max 를 넘으면 스크롤(넘기 전엔 성장).
    private var clampedTextHeight: CGFloat {
        min(max(measuredTextHeight, resize.minHeight), resize.maxHeight ?? .greatestFiniteMagnitude)
    }

    // 여러 줄 입력: 시스템 폰트(SUITE 미적용). placeholder 는 빈 값일 때 겹쳐 그린다.
    // ScrollView + 내용 높이 측정으로 normal(무한 성장)·limit(최대 후 스크롤)·fixed(고정+스크롤)를 한 코드로.
    @ViewBuilder private func textInput(_ spec: MHTextAreaSpec) -> some View {
        ScrollView(.vertical) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(spec.placeholderColor)
                        .padding(.horizontal, MHTextAreaMetric.textHPadding)
                }
                TextField("", text: $text, axis: .vertical)
                    .focused($isFocused)
                    // 멀티라인이라 리턴키가 개행으로 소비돼 리턴키로는 키보드를 못 닫는다(단일행 MHTextField 와
                    // 갈리는 지점). 툴바가 이 컴포넌트의 탈출로다 — 포커스일 때만 기여해 같은 화면에
                    // TextArea 가 여럿이어도 '완료' 가 중복되지 않는다.
                    .toolbar {
                        if isFocused {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("완료") { isFocused = false }
                                    .accessibilityIdentifier("MHTextArea.doneButton")
                            }
                        }
                    }
                    // 입력 요소에만 붙인다 — 바깥 modifier 는 heading·카운터까지 물들여 선택자가 다중 매치된다.
                    .accessibilityIdentifier(identifier ?? "MHTextArea.input")
                    .foregroundStyle(spec.valueTextColor)
                    .padding(.horizontal, MHTextAreaMetric.textHPadding)
                    .background(GeometryReader { g in
                        Color.clear.preference(key: MHTextAreaHeightKey.self, value: g.size.height)
                    })
            }
            .font(.system(size: MHTextAreaMetric.inputFontSize))
            .lineSpacing(MHTextAreaMetric.lineSpacing)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(height: clampedTextHeight)
        .scrollDisabled(measuredTextHeight <= clampedTextHeight)   // 내용이 안 넘치면 스크롤 잠금(바운스 방지)
        .onPreferenceChange(MHTextAreaHeightKey.self) { measuredTextHeight = $0 }
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
    // (TextArea 비활성 테두리는 Line/Normal/Neutral — TextField 의 Alternative 와 다름. Figma 135822 실측)
    var borderColor: Color {
        if !isEnabled { return .mhLineNormalNeutral }
        if status == .negative { return .mhStatusNegative.opacity(isFocused ? 0.43 : 0.28) }
        if isFocused { return .mhPrimaryNormal.opacity(0.43) }
        return .mhLineNormalNeutral
    }
    var borderWidth: CGFloat { (isEnabled && isFocused) ? 2 : 1 }

    var descriptionColor: Color { status == .negative ? .mhStatusNegative : .mhLabelAlternative }
    var valueTextColor: Color { isEnabled ? .mhLabelNormal : .mhLabelAlternative }
    var placeholderColor: Color { isEnabled ? .mhLabelAssistive : .mhLabelDisable }
}

// 텍스트 영역 내용 높이 측정용 PreferenceKey (성장 후 스크롤 전환).
private struct MHTextAreaHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
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

// 한 상태 셀 — Figma 문서 셀과 동일 구성: heading "주제" + 입력 박스(카운터/텍스트버튼) + description.
// 실제 @State 바인딩이라 타이핑하면 placeholder 가 사라지고 지우면 다시 나타난다(초깃값으로 빈/채움 상태를 시연).
private struct MHTextAreaStateCell: View {
    let label: String
    @State private var text: String
    let status: MHTextAreaStatus
    let disabled: Bool

    init(label: String, text: String, status: MHTextAreaStatus = .normal, disabled: Bool = false) {
        self.label = label
        self._text = State(initialValue: text)
        self.status = status
        self.disabled = disabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
            MHTextArea(
                "메시지를 입력해 주세요.",
                text: $text,
                heading: "주제",
                description: "메시지에 마침표를 찍어요.",
                status: status
            ) {
                MHCharacterCounter(count: text.count, limit: 2000)
            } bottomTrailing: {
                MHTextButton("텍스트") {}
            }
            .disabled(disabled)
        }
    }
}

// Figma `Textinput/Textarea` 상태 매트릭스 중 정적으로 고정되는 6종(status × active × disable).
// focus 상태(Primary 43%·2px 테두리)는 `@FocusState` 기반이라 정적 프리뷰로 못 박는다 →
// 아래 "입력·포커스" 프리뷰에서 탭하면 focus/active-focus 테두리를 실제로 확인.
#Preview("MHTextArea · 상태") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            MHTextAreaStateCell(label: "기본 (Inactive)", text: "")
            MHTextAreaStateCell(label: "입력됨 (Active)", text: "회의 내용을 정리했어요.")
            MHTextAreaStateCell(label: "에러 (Negative)", text: "", status: .negative)
            MHTextAreaStateCell(label: "에러·입력 (Negative·Active)", text: "회의 내용을 정리했어요.", status: .negative)
            MHTextAreaStateCell(label: "비활성 (Disabled)", text: "", disabled: true)
            MHTextAreaStateCell(label: "비활성·입력 (Disabled·Active)", text: "회의 내용을 정리했어요.", disabled: true)
        }
        .padding()
    }
    .frame(width: 367)
}

// 실제 입력 — 탭하면 focus 테두리(Primary 43%·2px, 에러는 빨강), 타이핑하면 성장(resize).
// Figma 의 Focus / Active·Focus / Error·Focus 상태와 resize 동작을 상호작용으로 확인한다.
#Preview("MHTextArea · 입력·포커스") {
    struct Host: View {
        @State private var normal = ""
        @State private var error = "형식에 맞지 않는 값이에요."
        var body: some View {
            ScrollView {
                VStack(spacing: 20) {
                    MHTextArea(
                        "메시지를 입력해 주세요.",
                        text: $normal,
                        heading: "주제",
                        isRequired: true,
                        description: "메시지에 마침표를 찍어요.",
                        resize: .limit(minLines: 1, maxLines: 5)
                    ) {
                        MHCharacterCounter(count: normal.count, limit: 2000)
                    } bottomTrailing: {
                        MHTextButton("전송") {}
                    }

                    MHTextArea(
                        "메시지를 입력해 주세요.",
                        text: $error,
                        heading: "주제",
                        description: "형식에 맞지 않아요.",
                        status: .negative
                    ) {
                        MHCharacterCounter(count: error.count, limit: 2000)
                    } bottomTrailing: {
                        MHTextButton("전송") {}
                    }
                }
                .padding()
            }
            .frame(width: 367)
        }
    }
    return Host()
}
