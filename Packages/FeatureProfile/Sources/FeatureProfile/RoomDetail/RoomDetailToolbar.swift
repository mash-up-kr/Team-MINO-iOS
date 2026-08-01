import DesignSystem
import SwiftUI

/// full 단계에서 목록 위에 붙는 줄 — 좌측 정렬 드롭다운 트리거, 우측 리스트/카드 보기 전환.
/// Figma 1672:65908 — pt16 pb8 px20.
struct RoomDetailToolbar: View {
    let sort: RoomDetailSort
    let viewMode: RoomDetailViewMode
    let isSortExpanded: Bool
    let onToggleSort: () -> Void
    let onSelectViewMode: (RoomDetailViewMode) -> Void

    var body: some View {
        HStack(spacing: 0) {
            sortTrigger
            Spacer(minLength: 8)
            viewModeToggle
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var sortTrigger: some View {
        Button(action: onToggleSort) {
            HStack(spacing: 0) {
                Text(sort.rawValue)
                    .mhTypography(.body1ReadingMedium)
                    .foregroundStyle(.mhPrimaryNormal)
                Image(.caretDown)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.mhPrimaryNormal)
                    .rotationEffect(.degrees(isSortExpanded ? 180 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("정렬 기준: \(sort.rawValue)")
        .accessibilityIdentifier("RoomDetail.sortTrigger")
    }

    // 선택된 보기 모드만 Label/Normal 로 강조하고 나머지는 Label/Alternative (Figma Interaction 색 기준)
    private var viewModeToggle: some View {
        HStack(spacing: 8) {
            toggleButton(.list, icon: .list, label: "리스트로 보기", identifier: "RoomDetail.viewMode.list")
            toggleButton(.grid, icon: .thumbnail, label: "카드로 보기", identifier: "RoomDetail.viewMode.grid")
        }
    }

    private func toggleButton(
        _ mode: RoomDetailViewMode,
        icon: MHIcon,
        label: String,
        identifier: String
    ) -> some View {
        RoomDetailPlainIconButton(
            icon: icon,
            tint: viewMode == mode ? .mhLabelNormal : .mhLabelAlternative,
            hitSize: 32,   // 두 버튼이 8pt 간격으로 붙어 있어 44 로 두면 탭 영역이 겹친다
            accessibilityLabel: label
        ) {
            onSelectViewMode(mode)
        }
        // 버튼 자체는 44pt 탭 영역을 갖되, 레이아웃 폭은 시안의 아이콘 크기(24)로 되돌려
        // 아이콘 사이 간격이 8pt 로 보이게 한다(탭 영역은 서로 겹쳐도 무방).
        .frame(width: 24, height: 24)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(viewMode == mode ? [.isSelected] : [])
    }
}
