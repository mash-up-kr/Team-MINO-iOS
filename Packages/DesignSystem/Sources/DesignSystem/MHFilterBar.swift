import SwiftUI

// MARK: - Filter Bar

/// 정렬 드롭다운 + 카테고리 칩 바를 한 줄에 담은 필터 바. Figma `Chip_Room`(node 15852:88538).
///
/// 정렬 버튼을 누르면 아래에 정렬 옵션 메뉴(``MHMenu``)가 열리고, 항목을 고르면 `selectedSort` 가 갱신되며
/// 닫힌다. 우측은 가로 스크롤 카테고리 칩 바(``MHCategory``). 메뉴 열림/닫힘만 내부 상태이고, 선택 값은
/// 호출부(바인딩)가 소유한다. 메뉴 바깥 탭 닫힘은 화면 레벨 몫(여기선 버튼 재탭·항목 선택으로 닫힘).
///
/// ```swift
/// MHFilterBar(
///     sortOptions: ["거리순", "최신순"], selectedSort: $sort,
///     categories: ["전체", "카페"], selectedCategory: $category
/// )
/// ```
public struct MHFilterBar: View {
    private let sortOptions: [String]
    @Binding private var selectedSort: Int
    private let categories: [String]
    @Binding private var selectedCategory: Int

    @State private var sortMenuOpen = false

    private let sortButtonHeight: CGFloat = 40
    private let menuWidth: CGFloat = 140
    private let menuGap: CGFloat = 8

    public init(
        sortOptions: [String],
        selectedSort: Binding<Int>,
        categories: [String],
        selectedCategory: Binding<Int>
    ) {
        self.sortOptions = sortOptions
        self._selectedSort = selectedSort
        self.categories = categories
        self._selectedCategory = selectedCategory
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            sortButton
            MHCategory(categories, selection: $selectedCategory, size: .xLarge)
        }
        .padding(.top, 20)
        .padding(.bottom, 12)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // px16 은 이 화면 인스턴스 값 — 표준 MHButton medium(px20)과 달라 토큰만 맞춘 커스텀으로 정합.
    private var sortButton: some View {
        Button { sortMenuOpen.toggle() } label: {
            HStack(spacing: 5) {
                Text(sortOptions[selectedSort])
                    .mhTypography(.body2NormalMedium)
                    .foregroundStyle(.mhLabelNormal)
                Image(MHIcon.caretDown)
                    .resizable().scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.mhLabelNormal)
            }
            .padding(.horizontal, 16)
            .frame(height: sortButtonHeight)
        }
        .buttonStyle(MHFilterSortButtonStyle())
        .overlay(alignment: .topLeading) {
            if sortMenuOpen {
                sortMenu
                    .frame(width: menuWidth, alignment: .leading)
                    .offset(y: sortButtonHeight + menuGap)
                    .zIndex(1)
            }
        }
    }

    private var sortMenu: some View {
        MHMenu(sortOptions.indices.map { i in
            MHMenuItem(sortOptions[i]) {
                selectedSort = i
                sortMenuOpen = false
            }
        })
    }
}

// MARK: - ButtonStyle

struct MHFilterSortButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.mhBackgroundNormalNormal)
            .overlay {
                if configuration.isPressed {
                    Color.mhLabelNormal.opacity(0.18)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10).strokeBorder(.mhLineNormalNeutral, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview("MHFilterBar") {
    struct Host: View {
        @State private var sort = 2
        @State private var category = 0
        var body: some View {
            MHFilterBar(
                sortOptions: ["거리순", "오래된순", "최신순", "코멘트순"], selectedSort: $sort,
                categories: ["전체", "카페", "음식점", "숙소", "관광"], selectedCategory: $category
            )
        }
    }
    return Host()
}
