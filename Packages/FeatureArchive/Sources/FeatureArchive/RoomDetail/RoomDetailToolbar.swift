import DesignSystem
import SwiftUI

/// full 단계 목록 위 줄 — 좌측 정렬 드롭다운 트리거, 우측 리스트/카드 보기 전환.
struct RoomDetailToolbar<SortMenu: View>: View {
    /// Figma `Frame 419` 높이. 드롭다운을 트리거 바로 아래에 붙이는 기준이다.
    private static var triggerHeight: CGFloat { 26 }

    let sort: RoomDetailSort
    let viewMode: RoomDetailViewMode
    let isSortExpanded: Bool
    let onToggleSort: () -> Void
    let onSelectViewMode: (RoomDetailViewMode) -> Void
    @ViewBuilder let sortMenu: () -> SortMenu

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
                    .foregroundStyle(.mhLabelNeutral)
                    .rotationEffect(.degrees(isSortExpanded ? 180 : 0))
            }
            .frame(height: Self.triggerHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("정렬 기준: \(sort.rawValue)")
        .accessibilityIdentifier("RoomDetail.sortTrigger")
        .overlay(alignment: .topLeading) {
            if isSortExpanded {
                sortMenu().offset(y: Self.triggerHeight)
            }
        }
    }

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
            hitSize: 32,
            accessibilityLabel: label
        ) {
            onSelectViewMode(mode)
        }
        // 탭 영역은 32 로 두되 레이아웃 폭은 아이콘 크기로 되돌려 간격을 8pt 로 맞춘다
        .frame(width: 24, height: 24)
        .accessibilityIdentifier(identifier)
        .accessibilityAddTraits(viewMode == mode ? [.isSelected] : [])
    }
}
