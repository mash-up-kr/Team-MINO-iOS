import SwiftUI

/// 정렬 드롭다운 + 카테고리 칩 바를 한 줄에 담은 필터 바. Figma `Chip_Room`(node 15852:88538).
///
/// 정렬 버튼을 누르면 아래에 정렬 옵션 메뉴(``MHMenu``)가 열리고, 항목을 고르면 `selectedSort` 가 갱신되며
/// 닫힌다. 우측은 가로 스크롤 카테고리 칩 바(``MHCategory``).
///
/// 메뉴는 버튼 재탭·항목 선택·**바깥 탭**·카테고리 칩 선택으로 닫힌다. 열림 상태는 기본적으로 내부에서
/// 들지만, `sortMenuPresented` 로 호출부가 소유할 수 있다 — 바텀시트 드래그처럼 **화면만 아는 신호로
/// 닫아야 할 때** 필요하다(``MHLocationCard`` 의 `menuPresented` 와 같은 규약).
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

    private let externalSortMenuPresented: Binding<Bool>?
    @State private var internalSortMenuOpen = false

    private let sortButtonHeight: CGFloat = 40
    private let menuWidth: CGFloat = 140
    private let menuGap: CGFloat = 8
    // 메뉴를 body 좌표계 overlay 로 그리므로 offset 계산에 패딩이 필요하다 — 함께 움직이게 상수로 둔다.
    private let horizontalPadding: CGFloat = 20
    private let topPadding: CGFloat = 20

    public init(
        sortOptions: [String],
        selectedSort: Binding<Int>,
        categories: [String],
        selectedCategory: Binding<Int>,
        sortMenuPresented: Binding<Bool>? = nil
    ) {
        self.sortOptions = sortOptions
        self._selectedSort = selectedSort
        self.categories = categories
        self._selectedCategory = selectedCategory
        self.externalSortMenuPresented = sortMenuPresented
    }

    // 외부 바인딩이 있으면 그걸, 없으면 내부 상태를 여닫음 소스로 쓴다.
    private var sortMenuOpen: Binding<Bool> {
        externalSortMenuPresented ?? $internalSortMenuOpen
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            sortButton
            MHCategory(categories, selection: $selectedCategory, size: .xLarge)
        }
        .padding(.top, topPadding)
        .padding(.bottom, 12)
        .padding(.horizontal, horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        // 스크림과 메뉴를 둘 다 이 레벨 overlay 로 둔다 — 붙인 순서가 곧 z-order(스크림 아래, 메뉴 위).
        // 메뉴를 버튼 overlay 에 두면 버튼 크기 프레임 때문에 스크림을 화면 전체로 펼칠 수 없다.
        .overlay { dismissScrim }
        .overlay(alignment: .topLeading) { sortMenuOverlay }
        .zIndex(sortMenuOpen.wrappedValue ? 1 : 0)
        // 카테고리 칩은 이 컴포넌트 안에 있으므로 칩 선택 시 정렬 메뉴를 닫는 것도 여기 몫이다.
        .onChange(of: selectedCategory) { _, _ in sortMenuOpen.wrappedValue = false }
    }

    // 메뉴 바깥을 탭하면 닫는 투명 스크림. 화면 전체를 덮도록 크게 잡되(레이아웃엔 영향 없음),
    // 색이 없어 보이지 않는다. 메뉴는 이 위에 별도 오버레이로 얹혀 항목 탭은 그대로 동작한다.
    @ViewBuilder private var dismissScrim: some View {
        if sortMenuOpen.wrappedValue {
            Color.clear
                .frame(width: 10000, height: 10000)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.12)) { sortMenuOpen.wrappedValue = false }
                }
        }
    }

    // 정렬 버튼 바로 아래. body 좌표계라 버튼 위치(패딩)만큼 offset 을 더해 기존 배치를 유지한다.
    @ViewBuilder private var sortMenuOverlay: some View {
        if sortMenuOpen.wrappedValue {
            sortMenu
                .frame(width: menuWidth, alignment: .leading)
                .offset(x: horizontalPadding, y: topPadding + sortButtonHeight + menuGap)
        }
    }

    // px16 은 이 화면 인스턴스 값 — 표준 MHButton medium(px20)과 달라 토큰만 맞춘 커스텀으로 정합.
    private var sortButton: some View {
        Button { sortMenuOpen.wrappedValue.toggle() } label: {
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
    }

    private var sortMenu: some View {
        MHMenu(sortOptions.indices.map { i in
            MHMenuItem(sortOptions[i]) {
                selectedSort = i
                sortMenuOpen.wrappedValue = false
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
