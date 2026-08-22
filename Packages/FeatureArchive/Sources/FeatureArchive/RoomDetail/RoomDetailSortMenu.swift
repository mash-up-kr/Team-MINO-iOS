import DesignSystem
import SwiftUI

/// 툴바 정렬 트리거 아래에 뜨는 드롭다운. Figma `Menu/Menu`.
struct RoomDetailSortMenu: View {
    private static let rowHeight: CGFloat = 40

    let selected: RoomDetailSort
    let onSelect: (RoomDetailSort) -> Void

    var body: some View {
        VStack(spacing: 4) {
            ForEach(RoomDetailSort.allCases) { option in
                row(option)
            }
        }
        .padding(.vertical, 8)
        .frame(width: 140)
        .background(.mhBackgroundElevatedNormal)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.mhLineSolidNeutral, lineWidth: 1)
        }
        .mhShadow(.small, cornerRadius: 16)
        .accessibilityIdentifier("RoomDetail.sortMenu")
    }

    private func row(_ option: RoomDetailSort) -> some View {
        let isSelected = option == selected
        return Button {
            onSelect(option)
        } label: {
            Text(option.rawValue)
                .mhTypography(.body1NormalRegular)
                .foregroundStyle(.mhLabelNormal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: Self.rowHeight)
                .padding(.horizontal, 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.mhLabelNormal.opacity(0.04))
                    .padding(.horizontal, 8)
            }
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    RoomDetailSortMenu(selected: .pick) { _ in }
        .padding(40)
}
