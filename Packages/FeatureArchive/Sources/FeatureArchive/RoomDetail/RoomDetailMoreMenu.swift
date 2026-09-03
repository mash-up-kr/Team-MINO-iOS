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

/// 드롭다운 카드를 놓을 자리. **높이를 재지 않고** 정렬로 붙이기 위한 값들이다.
///
/// 처음엔 카드 높이를 `GeometryReader` + preference 로 재서 위로 펼 때 `offset` 을 계산했는데,
/// 그 preference 는 `overlayPreferenceValue` 클로저 **안에서** 올라가 값이 끝내 도달하지 않았다
/// (SwiftUI 가 preference 순환을 끊는 지점이자, 클로저가 재평가될 때마다 `@State` 가 새 identity 로
/// 잡히는 지점이기도 하다). 그 결과 "재는 동안 숨김" 이 영구 숨김이 되어 **peek 에서만** 메뉴가
/// 통째로 안 떴다. 재지 않으면 숨길 이유도 없다 —
///
/// - 위로 펼 때: `0 ..< (케밥 top − gap)` 높이의 상자에 **bottom** 정렬 → 카드 아래끝이 그 자리에 선다.
/// - 아래로 펼 때: 카드 높이를 그대로 hug 한 상자를 `케밥 bottom + gap` 만큼 내린다.
///
/// 두 경우 모두 상자 너비를 케밥 오른쪽 끝까지로 두고 **trailing** 정렬해 오른쪽 끝을 맞춘다.
/// 자리를 레이아웃 시스템이 한 번에 정하므로 측정→재배치 왕복이 없다.
struct RoomDetailMoreMenuPlacement: Equatable {
    /// 카드를 담을 상자의 너비. 오른쪽 끝이 케밥 오른쪽 끝에 닿는다.
    let boxWidth: CGFloat
    /// 상자 높이. `nil` 이면 카드 높이를 그대로 쓴다(아래로 펼 때).
    let boxHeight: CGFloat?
    /// 상자를 아래로 내릴 양.
    let offsetY: CGFloat
    /// 상자 안에서 카드가 붙을 모서리.
    let alignment: Alignment

    init(kebab: CGRect, opensUpward: Bool, gap: CGFloat) {
        boxWidth = kebab.maxX
        if opensUpward {
            // 케밥 위 공간이 카드보다 좁으면 카드가 상자 위로 넘치지만(frame 은 자르지 않는다)
            // 아래끝은 제자리에 남는다. 음수 높이만 막는다.
            boxHeight = max(0, kebab.minY - gap)
            offsetY = 0
            alignment = .bottomTrailing
        } else {
            boxHeight = nil
            offsetY = kebab.maxY + gap
            alignment = .topTrailing
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
    /// 케밥과 카드 사이 간격 — 시안 실측 8pt(half: 케밥 bottom 448 ↔ 카드 top 456).
    private static let gap: CGFloat = 8

    /// peek 에서만 위로 편다. 시트가 낮아 아래로 펴면 바로 밑의 방 제목·메모를 덮는다.
    private var placement: RoomDetailMoreMenuPlacement {
        RoomDetailMoreMenuPlacement(kebab: kebab, opensUpward: detent == .low, gap: Self.gap)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 바깥 탭으로 닫기. 화면 전체를 덮되 보이지 않는다 — 카드는 이 위에 얹힌다.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { store.send(.dismissMoreMenu) }

            // 상자 자체는 배경이 없어 탭을 먹지 않는다 — 빈 자리의 탭은 위 스크림으로 내려간다.
            MHMenu(items)
                .frame(width: Self.width)
                .accessibilityIdentifier("RoomDetail.moreMenu")
                .frame(
                    width: placement.boxWidth,
                    height: placement.boxHeight,
                    alignment: placement.alignment
                )
                .offset(y: placement.offsetY)
        }
    }

    /// 방장이면 편집·나가기, 아니면 나가기 하나. 구성 규칙은 카탈로그가 갖는다.
    private var items: [MHMenuItem] {
        RoomDetailMenuCatalog.moreItems(isOwner: store.state.isOwner) { item in
            store.send(.selectMoreMenuItem(item))
        }
    }
}
