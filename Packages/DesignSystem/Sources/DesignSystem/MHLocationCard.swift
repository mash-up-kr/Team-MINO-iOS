import SwiftUI

// MARK: - Location Card

/// 장소 하나를 보여주는 카드. Figma `Card/Location`(node 15852:88757).
///
/// 썸네일 + 제목 + 주소 + 더보기(⋮) 버튼에, 하단에 코멘트 수(버블 아이콘 + 숫자)와 멤버
/// 아바타 그룹(``MHAvatarGroup``)을 둔다. Figma 의 두 variant 는 `layout` 으로 받는다:
/// - ``MHLocationCardLayout/compact``: 썸네일이 **왼쪽**(94pt 정사각), 콘텐츠가 오른쪽.
/// - ``MHLocationCardLayout/expanded``: 썸네일이 제목 **아래**(가로 꽉 채운 4:3 큰 이미지).
///
/// 코멘트 수는 999 를 넘으면 `999+` 로 표기한다. 썸네일이 `nil` 이면 이미지 자리 플레이스홀더를 보여준다.
///
/// 더보기(⋮) 를 누르면 나오는 메뉴는 `menuItems`(``MHMenuItem``)로 주입한다. 항목이 있으면 ⋮ 가
/// 카드에 앵커된 ``MHMenu`` 를 토글하고(Figma `edit` = on/on_top), 없으면 `onMore` 콜백만 부른다.
/// 열림 방향은 `menuPlacement` 로 정한다(목록 아래쪽 행은 `.above` 로 위로 연다). 외부에서 여닫음을
/// 제어하려면 `menuPresented` 바인딩을 준다(미지정 시 카드 내부 상태로 관리).
///
/// > **목록에서 한 번에 하나만 열기**: 각 카드가 내부 상태를 쓰면 여러 개가 동시에 열릴 수 있다.
/// > 컨테이너가 "열린 카드 식별자" 하나(`@State selectedID`)를 두고, 각 카드에 그로부터 파생한
/// > 바인딩(`Binding(get: { selectedID == id }, set: { selectedID = $0 ? id : nil })`)을 주면
/// > 다른 카드를 열 때 이전 것이 자동으로 닫힌다.
///
/// 메뉴가 열려 있을 때 **바깥을 탭하면 닫힌다**(투명 스크림). 항목 선택·⋮ 재탭으로도 닫힌다.
///
/// > 메뉴가 열린 모습은 ``MHMenu`` 와 동일하게 `ImageRenderer` 로는 렌더되지 않아 **시뮬레이터로만
/// > 육안 확인**된다.
///
/// ```swift
/// MHLocationCard(title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
///                commentCount: 1200, members: [img1, img2])            // compact(기본)
/// MHLocationCard(thumbnail: Image("cover"), title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
///                commentCount: 8, members: [img1], layout: .expanded) { openMore() }
/// MHLocationCard(title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10", commentCount: 8,
///                menuItems: [MHMenuItem("다른 방에 공유") { share() },
///                            MHMenuItem("장소 삭제") { remove() },
///                            MHMenuItem("장소 이동") { move() }])       // ⋮ → 메뉴
/// ```
public struct MHLocationCard: View {
    private let thumbnail: Image?
    private let title: String
    private let address: String
    private let commentCount: Int
    private let members: [Image?]
    private let layout: MHLocationCardLayout
    private let menuItems: [MHMenuItem]
    private let menuPlacement: MHLocationCardMenuPlacement
    private let onMore: (() -> Void)?

    private let externalMenuPresented: Binding<Bool>?
    @State private var internalMenuPresented = false
    @State private var menuHeight: CGFloat = 0

    public init(
        thumbnail: Image? = nil,
        title: String,
        address: String,
        commentCount: Int,
        members: [Image?] = [],
        layout: MHLocationCardLayout = .compact,
        menuItems: [MHMenuItem] = [],
        menuPlacement: MHLocationCardMenuPlacement = .below,
        menuPresented: Binding<Bool>? = nil,
        onMore: (() -> Void)? = nil
    ) {
        self.thumbnail = thumbnail
        self.title = title
        self.address = address
        self.commentCount = commentCount
        self.members = members
        self.layout = layout
        self.menuItems = menuItems
        self.menuPlacement = menuPlacement
        self.externalMenuPresented = menuPresented
        self.onMore = onMore
    }

    // 외부 바인딩이 있으면 그걸, 없으면 내부 상태를 여닫음 소스로 쓴다.
    private var menuPresented: Binding<Bool> {
        externalMenuPresented ?? $internalMenuPresented
    }

    public var body: some View {
        Group {
            switch layout {
            case .compact:  compactBody
            case .expanded: expandedBody
            }
        }
        .padding(.vertical, 12)                         // Figma: py 12
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay { dismissScrim }                        // 바깥 탭 감지(메뉴 아래 레이어)
        .overlay(alignment: .topTrailing) { menuOverlay } // 메뉴(스크림 위)
        // 메뉴가 열린 카드를 형제(아래 카드 등) 위로 올린다 — 아래 카드가 열린 메뉴를 가리지 않도록.
        .zIndex(menuPresented.wrappedValue ? 1 : 0)
    }

    // 메뉴 바깥을 탭하면 닫는 투명 스크림. 화면 전체를 덮도록 크게 잡되(레이아웃엔 영향 없음),
    // 색이 없어 보이지 않는다. 메뉴는 이 위에 별도 오버레이로 얹혀 항목 탭은 그대로 동작한다.
    @ViewBuilder private var dismissScrim: some View {
        if menuPresented.wrappedValue, !menuItems.isEmpty {
            Color.clear
                .frame(width: 10000, height: 10000)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.12)) { menuPresented.wrappedValue = false }
                }
        }
    }

    // compact — 썸네일 왼쪽(94 정사각), 오른쪽에 제목 행 + 코멘트/아바타 행(고정 gap 24, top 정렬).
    private var compactBody: some View {
        HStack(alignment: .top, spacing: 12) {          // Figma: gap 12
            thumbView(ratio: .square).frame(width: 94)
            VStack(alignment: .leading, spacing: 24) {   // Figma: gap xl(24)
                titleRow
                bottomRow
            }
        }
    }

    // expanded — 제목 행, 그 아래 절반 너비 4:5 썸네일(좌측 정렬), 마지막에 코멘트/아바타 행.
    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 12) {       // Figma: gap 12
            titleRow
            thumbView(ratio: .r4x5)                      // Figma: 163.5×204 ≈ 4:5
                .frame(width: 164)                       // Figma: 163.5pt ≈ 164
            bottomRow
        }
    }

    // 제목 + 주소(각 한 줄 말줄임) + 더보기 버튼.
    private var titleRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {   // Figma: gap xs(4)
                line(title, .body1NormalBold, .mhLabelNormal)
                line(address, .label2Medium, .mhLabelAlternative)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            moreButton
        }
    }

    // 코멘트 수(버블 + 숫자) + 멤버 아바타 그룹. 멤버가 없으면 아바타 그룹은 숨긴다.
    private var bottomRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: 2) {                         // Figma: gap 2
                Image(MHIcon.bubble)
                    .resizable().scaledToFit()
                    .frame(width: layout.controlSize, height: layout.controlSize)
                    .foregroundStyle(.mhLabelAlternative)
                Text(countText)
                    .lineLimit(1)
                    .mhTypography(.label2Medium)
                    .foregroundStyle(.mhLabelAlternative)
            }
            Spacer(minLength: 8)
            if !members.isEmpty {
                MHAvatarGroup(members, variant: .person, size: .xSmall)
            }
        }
    }

    // 더보기(⋮) — 배경 없는 아이콘 버튼(색 Label/Alternative). compact 18 / expanded 24.
    // menuItems 가 있으면 메뉴를 토글하고, 없으면 onMore 콜백만 부른다.
    private var moreButton: some View {
        Button {
            if menuItems.isEmpty {
                onMore?()
            } else {
                withAnimation(.easeOut(duration: 0.12)) { menuPresented.wrappedValue.toggle() }
            }
        } label: {
            Image(MHIcon.moreVertical)
                .resizable().scaledToFit()
                .frame(width: layout.controlSize, height: layout.controlSize)
                .foregroundStyle(.mhLabelAlternative)
                // 히트 영역을 44pt 로 확장(아이콘은 우상단 고정) + 투명 영역까지 탭 인식.
                .frame(width: 44, height: 44, alignment: .topTrailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // ⋮ 에 앵커된 더보기 메뉴. 트레일링 정렬로 카드 오른쪽 끝(⋮ 위치)에 붙고, below 는 ⋮ 아래로,
    // above 는 ⋮ 위로 편다(Figma edit on / on_top). 항목 선택 시 액션 실행 후 자동으로 닫는다.
    @ViewBuilder private var menuOverlay: some View {
        if menuPresented.wrappedValue, !menuItems.isEmpty {
            MHMenu(closableMenuItems)
                .frame(width: 140)                       // Figma Menu w-140
                .background(GeometryReader { g in
                    Color.clear.preference(key: MHLocationCardMenuHeightKey.self, value: g.size.height)
                })
                .onPreferenceChange(MHLocationCardMenuHeightKey.self) { menuHeight = $0 }
                // below: ⋮ 아래끝(py12 + 아이콘) 바로 밑 / above: ⋮ 위로 메뉴 높이만큼 올림.
                .offset(y: menuPlacement == .below ? 12 + layout.controlSize : 4 - menuHeight)
                .transition(.opacity)
        }
    }

    // 원본 항목의 액션 뒤에 "메뉴 닫기"를 덧붙인 사본(선택하면 닫히도록).
    private var closableMenuItems: [MHMenuItem] {
        menuItems.map { item in
            MHMenuItem(
                item.label, caption: item.caption, trailing: item.trailing,
                isActive: item.isActive, isDisabled: item.isDisabled
            ) {
                item.action()
                menuPresented.wrappedValue = false
            }
        }
    }

    // 썸네일 — 지정 이미지가 있으면 ``MHThumbnail``, 없으면 플레이스홀더(둘 다 radius 12 + 테두리).
    @ViewBuilder private func thumbView(ratio: MHThumbnailRatio) -> some View {
        if let thumbnail {
            MHThumbnail(thumbnail, ratio: ratio, radius: true, border: true)
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.mhFillNormal)
                .aspectRatio(ratio.value, contentMode: .fit)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundStyle(.mhLabelDisable)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.mhLineNormalNeutral, lineWidth: 1)
                }
        }
    }

    // 999 초과는 999+ 로 절단(Figma).
    private var countText: String { commentCount > 999 ? "999+" : "\(commentCount)" }

    private func line(_ string: String, _ token: MHTypography, _ color: Color) -> some View {
        Text(string)
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(color)
            .mhTypography(token)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Layout

/// ``MHLocationCard`` 의 썸네일 배치. Figma `Card/Location` 의 thumbnail variant.
public enum MHLocationCardLayout: Sendable {
    /// 썸네일이 왼쪽(94pt 정사각), 콘텐츠가 오른쪽. 목록 한 줄에 적합.
    case compact
    /// 썸네일이 제목 아래(가로 꽉 채운 4:3 큰 이미지). 강조 표시에 적합.
    case expanded

    /// 더보기·버블 아이콘의 한 변(pt). compact 18 / expanded 24.
    var controlSize: CGFloat { self == .compact ? 18 : 24 }
}

// MARK: - Menu Placement

/// ``MHLocationCard`` 더보기 메뉴가 열리는 방향. Figma `Card/Location` 의 edit variant.
public enum MHLocationCardMenuPlacement: Sendable {
    /// ⋮ 아래로 편다(Figma `edit=on`). 목록 위쪽 행 기본.
    case below
    /// ⋮ 위로 편다(Figma `edit=on_top`). 아래쪽 행에서 화면 밖으로 나가지 않도록.
    case above
}

// 앵커 메뉴 높이 측정용(above 편성 시 위로 올릴 양 계산).
private struct MHLocationCardMenuHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

// 목록에서 "한 번에 하나만" 열리는 조율 예시 — 열린 카드 인덱스 하나를 컨테이너가 들고,
// 각 카드의 menuPresented 를 거기서 파생한다(다른 카드를 열면 이전 것이 자동으로 닫힘).
private struct MHLocationCardMenuDemo: View {
    @State private var openIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            card(0, layout: .compact, count: 1200)
            card(1, layout: .expanded, count: 8)
        }
        .frame(width: 335)
        .padding()
    }

    private func card(_ index: Int, layout: MHLocationCardLayout, count: Int) -> some View {
        MHLocationCard(
            title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
            commentCount: count, members: [nil], layout: layout,
            menuItems: menuPreviewItems(),
            menuPresented: Binding(
                get: { openIndex == index },
                set: { openIndex = $0 ? index : nil }
            )
        )
    }
}

#Preview("MHLocationCard") {
    MHLocationCardMenuDemo()
}

private func menuPreviewItems() -> [MHMenuItem] {
    [MHMenuItem("다른 방에 공유") { }, MHMenuItem("장소 삭제") { }, MHMenuItem("장소 이동") { }]
}

// ⋮ 를 눌러 실제로 메뉴를 여닫는 인터랙션 프리뷰(내부 상태 사용 — menuPresented 미지정).
#Preview("MHLocationCard · 메뉴 인터랙션") {
    MHLocationCard(title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10", commentCount: 8,
                   members: [nil], menuItems: menuPreviewItems())
        .frame(width: 335)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
}

// 더보기 메뉴 아래로 열림(Figma edit=on) — 위치 확인용 고정 열림(constant, 탭 토글 아님).
#Preview("MHLocationCard · 메뉴 아래") {
    MHLocationCard(title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10", commentCount: 8,
                   members: [nil], menuItems: menuPreviewItems(),
                   menuPlacement: .below, menuPresented: .constant(true))
        .frame(width: 335)
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .top)
}

// 더보기 메뉴 위로 열림(Figma edit=on_top). 메뉴가 펼쳐질 위 공간을 위해 카드를 하단에 붙인다.
#Preview("MHLocationCard · 메뉴 위") {
    MHLocationCard(title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10", commentCount: 8,
                   members: [nil], menuItems: menuPreviewItems(),
                   menuPlacement: .above, menuPresented: .constant(true))
        .frame(width: 335)
        .padding(24)
        .frame(maxHeight: .infinity, alignment: .bottom)
}
