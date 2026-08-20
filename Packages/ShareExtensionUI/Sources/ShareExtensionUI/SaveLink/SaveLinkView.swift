import Core
import DesignSystem
import SavePostUI
import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — Store 는 .task 에서 1회 lazy 생성

/// 공유받은 링크를 방에 저장하는 바텀시트. Figma `013-1 외부 공유 시 바텀시트`(node 2661:164102 외).
///
/// 시트 마크업은 홈과 공유하는 ``SavePostSheet`` 가 그리고, 여기서는 익스텐션 고유의 컨테이너
/// (호스트 화면 위 오버레이·바깥탭 닫기·완료 스낵바)만 맡는다.
///
/// Coordinator 대신 `makeStore` 클로저를 받는다: 익스텐션에는 Coordinator 가 없고
/// `ShareViewController` 가 Store 를 만들어 navigation 을 소비한다.
public struct SaveLinkView: View {
    private let makeStore: @MainActor () -> SaveLinkStore
    @State private var store: SaveLinkStore?

    public init(makeStore: @escaping @MainActor () -> SaveLinkStore) {
        self.makeStore = makeStore
    }

    public var body: some View {
        // `ignoresSafeArea` 는 GeometryReader 가 아니라 그 **안쪽**에 건다 — 밖에 걸면
        // proxy.safeAreaInsets 가 0 으로 보고돼 시트가 홈 인디케이터 높이만큼 짧아진다.
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                // 시트 밖은 호스트 화면이 그대로 비친다(시안의 회색은 딤이 아니라 "위에 올라온다"는 표시).
                // `Color.clear` 는 탭을 받지 못해 최소 불투명도를 준다 — 색이 아니라 히트 테스트가 목적이다.
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { store?.send(.tapClose) }

                if let store {
                    if store.state.isSaved {
                        savedFeedback
                    } else {
                        sheet(store: store, safeAreaBottom: proxy.safeAreaInsets.bottom)
                            .transition(.move(edge: .bottom))
                    }
                } else {
                    ProgressView()
                        .task { store = makeStore() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .animation(.spring(duration: 0.3), value: store?.state.isSaved)
        }
    }

    /// 시트 본체 + 익스텐션 쪽 컨테이너(고정 높이·둥근 상단 배경).
    /// 홈은 시스템 `.sheet` 가 이 둘을 대신하므로 ``SavePostSheet`` 는 컨테이너를 그리지 않는다.
    private func sheet(store: SaveLinkStore, safeAreaBottom: CGFloat) -> some View {
        SavePostSheet(
            rooms: store.state.rooms.map(SavePostRoom.init(_:)),
            checkedRoomIDs: store.state.checkedRoomIDs,
            disabledRoomIDs: store.state.savedRoomIDs,
            canSubmit: store.state.canSubmit,
            safeAreaBottom: safeAreaBottom,
            identifierPrefix: "SaveLink",
            onToggleRoom: { store.send(.toggleRoom($0)) },
            onSave: { store.send(.tapSave) }
        )
        .frame(height: SavePostSheetMetrics.height(roomCount: store.state.rooms.count,
                                                  safeAreaBottom: safeAreaBottom))
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .fill(Color.mhBackgroundElevatedNormal)
        }
    }

    /// 저장이 끝나면 시트는 사라지고 스낵바만 남는다. Figma `013-2`(화면 바닥에서 40).
    private var savedFeedback: some View {
        MHSnackbar(title: "저장이 완료됐습니다.", icon: .check)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .accessibilityIdentifier("SaveLink.completionSnackbar")
    }
}

private extension SavePostRoom {
    /// 익스텐션이 들고 있는 방(`Core.SharedRoom`) → 시트 표시용 값.
    /// 썸네일 정보는 아직 공유 저장소에 없어 기본 색으로 둔다.
    init(_ room: SharedRoom) {
        self.init(id: room.id, name: room.name, memo: room.memo, placeCount: room.placeCount)
    }
}

#Preview("방 5개 — 644") {
    ZStack(alignment: .bottom) {
        // 실제로는 호스트 화면이 비친다 — 시트 경계를 보려고 깔아둔 배경.
        Color.mhMaterialDimmer.ignoresSafeArea()
        SavePostSheet(
            rooms: SharedRoom.samples.map(SavePostRoom.init(_:)),
            checkedRoomIDs: ["2"],
            disabledRoomIDs: ["2"],
            canSubmit: false,
            safeAreaBottom: SavePostSheetMetrics.designSafeAreaBottom,
            identifierPrefix: "SaveLink",
            onToggleRoom: { _ in },
            onSave: {}
        )
        .frame(height: SavePostSheetMetrics.height(roomCount: SharedRoom.samples.count, safeAreaBottom: 34))
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .fill(Color.mhBackgroundElevatedNormal)
        }
    }
}
