import SwiftUI

/// 활성 칩의 강조 방식. `normal`=활성 시 solid 검정(Label/Strong), `alternative`=활성 시 옅은 Primary 아웃라인. Figma `variant`.
public enum MHCategoryVariant: Sendable { case normal, alternative }

/// 카테고리 크기. Figma `size` = Small/Medium/Large/XLarge → 칩 높이 24/32/36/40.
public enum MHCategorySize: Sendable {
    case small, medium, large, xLarge

    // Figma Category size → Chip size(높이). Small24=Chip XSmall, Medium32=Small, Large36=Normal, XLarge40=Large.
    var chip: MHChipSize {
        switch self {
        case .small:  return .xsmall
        case .medium: return .small
        case .large:  return .medium
        case .xLarge: return .large
        }
    }
}

/// 정보를 주제/그룹으로 나눠 고르는 가로 칩 바(단일 선택). Figma `Category/Category`.
///
/// `items` 를 가로로 늘어놓고(겹침 없이 6pt 간격), `selection`(선택 인덱스)에 해당하는 칩만 활성으로
/// 그린다. 내용이 넘치면 가로 스크롤되며 뒤쪽 가장자리가 페이드된다. 오른쪽 끝에는 `trailing`
/// 슬롯(필터/더보기 아이콘 버튼 등)을 얹을 수 있다.
///
/// 칩은 ``MHChip`` 을 재사용한다 — `variant`·활성 여부로 solid/outlined 를 고른다:
/// normal+활성=solid(검정), 그 외=outlined(비활성 흰+테두리 / alternative 활성=옅은 Primary).
///
/// ```swift
/// MHCategory(["전체", "개발", "디자인", "기획"], selection: $tab)                 // 기본: normal·medium
/// MHCategory(cats, selection: $tab, variant: .alternative, size: .large)          // 옅은 강조·36pt
/// MHCategory(cats, selection: $tab, horizontalPadding: true) { filterButton }     // 좌우 여백 + 트레일링
/// ```
public struct MHCategory<Trailing: View>: View {
    private let items: [String]
    @Binding private var selection: Int
    private let variant: MHCategoryVariant
    private let size: MHCategorySize
    private let horizontalPadding: Bool
    private let verticalPadding: Bool
    private let trailing: Trailing

    // 칩 사이 간격(Figma Wrapper gap)은 사이즈마다 다르다 — 실측: Medium 6, XLarge 10
    // (XLarge 는 홈 필터바 `Category/Category` 인스턴스, 칩 73·67·80 이 x=0·83·160 에 놓인다).
    // Small·Large 는 아직 그 사이즈 시안을 만나지 못해 가까운 쪽을 따른다 — 만나면 실측해 고친다.
    private var chipGap: CGFloat {
        switch size {
        case .small, .medium: return 6
        case .large, .xLarge: return 10
        }
    }
    private let sidePadding: CGFloat = 20      // Figma horizontalPadding=True (Leading px-20)
    private let vSpace: CGFloat = 8            // Figma verticalPadding=True (Space h-8)
    private let trailingGap: CGFloat = 20      // Figma Content gap-20 (칩↔아이콘버튼)
    private let trailingInset: CGFloat = 16    // Figma Trailing pr-16 (padding 시)
    private let fadeWidth: CGFloat = 20        // 스크롤 가장자리 페이드 근사

    public init(
        _ items: [String],
        selection: Binding<Int>,
        variant: MHCategoryVariant = .normal,
        size: MHCategorySize = .medium,
        horizontalPadding: Bool = false,
        verticalPadding: Bool = false,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.items = items
        self._selection = selection
        self.variant = variant
        self.size = size
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.trailing = trailing()
    }

    private var hasTrailing: Bool { Trailing.self != EmptyView.self }

    public var body: some View {
        HStack(spacing: 0) {
            chipScroll
            if hasTrailing {
                trailing
                    .padding(.leading, horizontalPadding ? 0 : trailingGap)   // padding 시엔 스크롤 우측 여백이 gap 역할
                    .padding(.trailing, horizontalPadding ? trailingInset : 0)
            }
        }
    }

    private var chipScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: chipGap) {
                ForEach(items.indices, id: \.self) { i in
                    chip(index: i)
                }
            }
            .padding(.vertical, verticalPadding ? vSpace : 0)
            .padding(.horizontal, horizontalPadding ? sidePadding : 0)
        }
        .mask(trailingFade)   // 뒤쪽 가장자리 페이드(스크롤 여지 암시)
    }

    private func chip(index i: Int) -> some View {
        let active = i == selection
        // normal 활성만 solid(검정). 비활성·alternative 는 outlined(흰+테두리 / alternative 활성=옅은 Primary).
        let chipVariant: MHChipVariant = (variant == .normal && active) ? .solid : .outlined
        return MHChip(items[i], variant: chipVariant, size: size.chip, isActive: active) {
            selection = i
        }
    }

    // 트레일링 fadeWidth 만 검정→투명(마스크). 콘텐츠가 넘칠 때 뒤쪽이 자연스레 사라진다.
    private var trailingFade: some View {
        HStack(spacing: 0) {
            Rectangle().fill(.black)
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: fadeWidth)
        }
    }
}

#Preview("MHCategory") {
    struct Host: View {
        @State private var sel = 0
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                MHCategory(["전체", "개발", "디자인", "기획", "PM"], selection: $sel)
                MHCategory(["전체", "개발", "디자인"], selection: $sel, variant: .alternative)
                MHCategory(["전체", "개발", "디자인", "기획", "PM", "마케팅", "데이터"], selection: $sel, horizontalPadding: true) {
                    Image(systemName: "slider.horizontal.3").foregroundStyle(.mhLabelNormal)
                }
            }
        }
    }
    return Host()
}
