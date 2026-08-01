import DesignSystem
import SwiftUI

/// 툴바 정렬 트리거 아래에 뜨는 드롭다운. Figma `004-1-3 full` 의 열린 상태.
/// 시트 콘텐츠 위에 겹쳐 놓는 오버레이라 자체 배경·그림자를 갖는다.
struct RoomDetailSortMenu: View {
    /// 항목 하나의 높이.
    static let rowHeight: CGFloat = 44
    /// 메뉴 전체 높이. 툴바 아래로 떨어뜨릴 offset 계산에 쓴다.
    static var height: CGFloat { rowHeight * CGFloat(RoomDetailSort.allCases.count) }

    let selected: RoomDetailSort
    let onSelect: (RoomDetailSort) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(RoomDetailSort.allCases) { option in
                row(option)
            }
        }
        .frame(width: 140)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.mhBackgroundElevatedNormal)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .mhShadow(.medium, cornerRadius: 12)
        .accessibilityIdentifier("RoomDetail.sortMenu")
    }

    private func row(_ option: RoomDetailSort) -> some View {
        let isSelected = option == selected
        return Button {
            onSelect(option)
        } label: {
            Text(option.rawValue)
                .mhTypography(.body2NormalMedium)
                .foregroundStyle(isSelected ? .mhLabelNormal : .mhLabelAlternative)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .frame(height: Self.rowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Color.mhFillAlternative : .clear)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    RoomDetailSortMenu(selected: .pick) { _ in }
        .padding(40)
}
