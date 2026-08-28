import DesignSystem
import SwiftUI

/// 헤더 케밥 버튼의 화면 위치를 시트 **밖**으로 알리는 앵커.
///
/// 시안 004-1 ② 2-2 는 peek 에서 이 드롭다운을 시트 위(지도 위)로 띄운다. 그런데 시트 콘텐츠는
/// `MHBottomSheet` 이 `clipShape` 로 잘라내므로 시트 안에서 그리면 위로 튀어나온 부분이 사라진다 —
/// 그래서 버튼 위치만 preference 로 올려 보내고, 그림은 시트를 담은 껍데기가 그린다.
private struct RoomDetailMoreAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// 메뉴 카드 높이 측정용 — 위로 펼 때 얼마나 올릴지 계산한다.
private struct RoomDetailMoreMenuHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

extension View {
    /// 헤더 케밥 버튼에 붙인다 — 이 버튼이 드롭다운이 붙을 기준점이 된다.
    func roomDetailMoreMenuAnchor() -> some View {
        anchorPreference(key: RoomDetailMoreAnchorKey.self, value: .bounds) { $0 }
    }

    /// 시트를 담은 껍데기에 붙인다 — 시트 클립 밖에서 드롭다운을 그린다.
    ///
    /// - Parameters:
    ///   - store: 방 상세 Store. 없으면(방 리스트·장소 상세) 아무것도 그리지 않는다.
    ///   - detent: 지금 시트 단계. peek 여부로 여는 방향이 갈린다.
    func roomDetailMoreMenu(store: RoomDetailStore?, detent: MHBottomSheetDetent) -> some View {
        overlayPreferenceValue(RoomDetailMoreAnchorKey.self) { anchor in
            if let store, let anchor, store.state.isMoreMenuPresented {
                GeometryReader { proxy in
                    RoomDetailMoreMenu(store: store, detent: detent, kebab: proxy[anchor])
                }
            }
        }
    }
}

/// 방 상세 헤더 케밥 드롭다운. Figma `004-5 방 더보기 버튼 클릭시`.
///
/// 케밥의 오른쪽 끝에 맞춰 붙고, peek 에서는 버튼 **위로**, 그 밖의 단계에서는 **아래로** 편다
/// (004-1 ② 2-2 — "004-1-1_방 상세 peek 일때만 상단으로 표기 이외에 뷰는 하단 표기로 동일").
private struct RoomDetailMoreMenu: View {
    let store: RoomDetailStore
    let detent: MHBottomSheetDetent
    /// 케밥 버튼의 위치(껍데기 좌표계).
    let kebab: CGRect

    /// 카드 너비. 장소 카드 케밥 메뉴와 같은 값(Figma `Menu/Menu` 140pt).
    private static let width: CGFloat = 140
    /// 케밥과 카드 사이 간격 — 시안 실측 8pt(peek: 케밥 top 644 ↔ 카드 bottom 635).
    private static let gap: CGFloat = 8

    @State private var height: CGFloat = 0

    /// peek 에서만 위로 편다. 시트가 낮아 아래로 펴면 바로 밑의 방 제목·메모를 덮는다.
    private var opensUpward: Bool { detent == .low }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 바깥 탭으로 닫기. 화면 전체를 덮되 보이지 않는다 — 카드는 이 위에 얹힌다.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { store.send(.dismissMoreMenu) }

            MHMenu(items)
                .frame(width: Self.width)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: RoomDetailMoreMenuHeightKey.self, value: proxy.size.height)
                    }
                )
                .onPreferenceChange(RoomDetailMoreMenuHeightKey.self) { height = $0 }
                .offset(x: kebab.maxX - Self.width, y: topY)
                // 위로 펼 자리는 높이를 재야 정해진다 — 재기 전 한 프레임이 엉뚱한 곳에 뜨지 않게 숨긴다.
                .opacity(opensUpward && height == 0 ? 0 : 1)
                .accessibilityIdentifier("RoomDetail.moreMenu")
        }
    }

    private var topY: CGFloat {
        opensUpward ? kebab.minY - Self.gap - height : kebab.maxY + Self.gap
    }

    /// 방장이면 편집·나가기, 아니면 나가기 하나. 구성 규칙은 카탈로그가 갖는다.
    private var items: [MHMenuItem] {
        RoomDetailMenuCatalog.moreItems(isOwner: store.state.isOwner) { item in
            store.send(.selectMoreMenuItem(item))
        }
    }
}
