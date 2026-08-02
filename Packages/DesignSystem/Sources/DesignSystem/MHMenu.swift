import SwiftUI

// MARK: - Menu

/// 메뉴 항목의 trailing 슬롯. 단색 아이콘(24pt) 또는 보조 텍스트(단축키·값 등).
public enum MHMenuTrailing: Sendable {
    case icon(MHIcon)
    case text(String)
}

/// 메뉴 항목 하나 — 라벨(+옵션 caption·trailing) + 탭 액션. `isActive`(선택 강조)·`isDisabled`(비활성).
public struct MHMenuItem {
    let label: String
    let caption: String?
    let trailing: MHMenuTrailing?
    let isActive: Bool
    let isDisabled: Bool
    let action: () -> Void

    public init(
        _ label: String,
        caption: String? = nil,
        trailing: MHMenuTrailing? = nil,
        isActive: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.caption = caption
        self.trailing = trailing
        self.isActive = isActive
        self.isDisabled = isDisabled
        self.action = action
    }
}

/// 선택 가능한 행동을 나열하는 드롭다운/메뉴 카드. Figma `Menu/Menu`(variant=Normal).
///
/// elevated 흰 카드(둥근 16 · 얇은 테두리 · Shadow/Normal/Small)에 항목을 세로로 쌓고, 넘치면
/// (`maxHeight`, 기본 400) 세로 스크롤한다. 각 항목은 눌림 시 옅은 하이라이트(Label/Normal 4%,
/// 카드 끝에서 8pt 안쪽, 둥근 12)가 깔린다. 하단에 `actionArea` 슬롯(예: 텍스트 버튼 + CTA)을 붙이면
/// 상단 구분선(`Line/Solid/Alternative`)과 12pt 패딩이 자동으로 둘러진다 — caller 는 버튼 내용만 채운다.
///
/// > radio/checkbox 변형은 별도 토글 컴포넌트가 필요해 후속. 스크롤·그림자는 시뮬레이터로만 육안 확인
/// > 가능(ImageRenderer 미지원).
///
/// ```swift
/// MHMenu([
///     MHMenuItem("복사", trailing: .text("⌘C")) { copy() },
///     MHMenuItem("이름 바꾸기") { rename() },
///     MHMenuItem("삭제", trailing: .icon(.trash)) { delete() },
/// ])
/// MHMenu(items) { MHActionArea(...) }   // 하단 액션영역
/// ```
public struct MHMenu<ActionArea: View>: View {
    private let items: [MHMenuItem]
    private let maxHeight: CGFloat
    private let cellVerticalPadding: CGFloat
    private let actionArea: ActionArea

    public init(
        _ items: [MHMenuItem],
        maxHeight: CGFloat = 400,
        cellVerticalPadding: CGFloat = 8,                    // Figma Cell Padding 8px(기본)/12px
        @ViewBuilder actionArea: () -> ActionArea = { EmptyView() }
    ) {
        self.items = items
        self.maxHeight = maxHeight
        self.cellVerticalPadding = cellVerticalPadding
        self.actionArea = actionArea()
    }

    private var hasActionArea: Bool { ActionArea.self != EmptyView.self }

    @State private var listContentHeight: CGFloat = 0

    public var body: some View {
        VStack(spacing: 0) {
            list
            if hasActionArea { actionAreaContainer }
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mhBackgroundElevatedNormal))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.mhLineSolidNeutral, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .mhShadow(.small, cornerRadius: 16)                   // Figma Shadow/Normal/Small
    }

    // 항목 리스트 — Figma `max-h-[400px]` 은 "최대 400": 내용에 맞춰 높이를 hug 하고 넘칠 때만 스크롤한다.
    // ScrollView 는 세로로 greedy 라 그대로 두면 항목이 적어도 카드가 maxHeight 까지 늘어나 아래에 빈 공간이 생긴다.
    // → 내용 높이(py-8 포함)를 재서 min(내용, maxHeight) 으로 고정(MHTextArea 의 성장-후-스크롤 패턴과 동일).
    private var list: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 4) {                              // Figma Contents gap-4
                ForEach(items.indices, id: \.self) { i in
                    cell(items[i])
                }
            }
            .padding(.horizontal, 20)                         // Figma Container px-20
            .padding(.vertical, 8)                            // Figma Container py-8
            .background(GeometryReader { g in
                Color.clear.preference(key: MHMenuContentHeightKey.self, value: g.size.height)
            })
        }
        .frame(height: min(listContentHeight, maxHeight))     // 내용에 맞춰 hug (최대 maxHeight)
        .scrollDisabled(listContentHeight <= maxHeight)       // 안 넘치면 스크롤 잠금(바운스 방지)
        .onPreferenceChange(MHMenuContentHeightKey.self) { listContentHeight = $0 }
    }

    // 하단 액션영역 — 상단 구분선(Line/Solid/Alternative) + p-12 + elevated 배경. 내용(버튼)은 caller 가 채운다.
    private var actionAreaContainer: some View {
        actionArea
            .frame(maxWidth: .infinity)
            .padding(12)                                      // Figma Menu Action Area p-12
            .background(Color.mhBackgroundElevatedNormal)
            .overlay(alignment: .top) {
                Rectangle().fill(Color.mhLineSolidAlternative).frame(height: 1)   // border-top
            }
    }

    // 항목 셀 — 라벨(+caption·trailing), py=cellVerticalPadding, 눌림 하이라이트는 카드 끝 8pt 안쪽까지 확장.
    // active=Medium+Primary/Normal, disable=Label/Disable(비상호작용).
    private func cell(_ item: MHMenuItem) -> some View {
        Button(action: item.action) {
            HStack(spacing: 8) {                              // Figma Wrapper gap-8
                VStack(alignment: .leading, spacing: 4) {     // Figma Content gap-4 (라벨/캡션)
                    Text(item.label)
                        .mhTypography(item.isActive ? .body1NormalMedium : .body1NormalRegular)
                        .foregroundStyle(labelColor(item))
                        .frame(minHeight: 24, alignment: .leading)   // Figma Label min-h-24
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let caption = item.caption {
                        Text(caption)
                            .mhTypography(.label2Regular)     // SUITE Regular 13
                            .foregroundStyle(item.isDisabled ? .mhLabelDisable : .mhLabelAlternative)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let trailing = item.trailing { trailingView(trailing, disabled: item.isDisabled) }
            }
            .padding(.vertical, cellVerticalPadding)          // Figma Container py (8/12)
            .contentShape(Rectangle())
        }
        .buttonStyle(MHMenuCellStyle())
        .disabled(item.isDisabled)
    }

    // 라벨 색: 비활성=Label/Disable, 선택=Primary/Normal, 기본=Label/Normal.
    private func labelColor(_ item: MHMenuItem) -> Color {
        if item.isDisabled { return .mhLabelDisable }
        return item.isActive ? .mhPrimaryNormal : .mhLabelNormal
    }

    @ViewBuilder private func trailingView(_ trailing: MHMenuTrailing, disabled: Bool) -> some View {
        let tint: Color = disabled ? .mhLabelDisable : .mhLabelAlternative
        switch trailing {
        case .icon(let icon):
            Image(icon).resizable().scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(tint)
        case .text(let text):
            Text(text)
                .mhTypography(.body1NormalRegular)
                .foregroundStyle(tint)
        }
    }
}

// MARK: - ButtonStyle (셀 눌림 하이라이트)

// 눌림 시 Label/Normal 4% 하이라이트(둥근 12), 카드 px-20 안쪽으로 12pt 확장해 카드 끝에서 8pt 안쪽에 닿게.
private struct MHMenuCellStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.mhLabelNormal.opacity(0.04))
                        .padding(.horizontal, -12)            // px-20 − inset 8 = 12 확장
                }
            }
    }
}

// 메뉴 리스트 내용 높이 측정용 PreferenceKey (hug → 넘치면 스크롤 전환).
private struct MHMenuContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

// Figma `Menu/Menu`(Variant=Normal) 기본 형태 — elevated 카드 + 텍스트 셀 리스트.
#Preview("MHMenu · 기본") {
    MHMenu([
        MHMenuItem("복사", isActive: true) {},
        MHMenuItem("붙여넣기") {},
        MHMenuItem("이름 바꾸기") {},
        MHMenuItem("복제") {},
        MHMenuItem("삭제") {},
    ])
    .frame(width: 240)
    .padding()
}

// 셀 상태: 기본 / active(Medium·Primary) / caption(부제목) / disable(Label/Disable) / trailing(아이콘·단축키).
#Preview("MHMenu · 셀 상태") {
    MHMenu([
        MHMenuItem("복사", trailing: .text("⌘C")) {},
        MHMenuItem("선택됨", isActive: true) {},
        MHMenuItem("공유", caption: "링크로 공유") {},
        MHMenuItem("내보내기", trailing: .icon(.download)) {},
        MHMenuItem("삭제", trailing: .icon(.trash), isDisabled: true) {},
    ])
    .frame(width: 240)
    .padding()
}

// 하단 액션영역(menuActionArea) — 상단 구분선 + 텍스트버튼 + CTA. cellVerticalPadding 12.
#Preview("MHMenu · 액션영역") {
    MHMenu(
        (0..<5).map { MHMenuItem("텍스트 \($0)") {} },
        cellVerticalPadding: 12
    ) {
        HStack {
            Text("텍스트").mhTypography(.body1NormalRegular).foregroundStyle(.mhLabelAlternative)
            Spacer()
            Text("확인").mhTypography(.label1NormalBold).foregroundStyle(.mhStaticWhite)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.mhLabelStrong))
        }
    }
    .frame(width: 280)
    .padding()
}
