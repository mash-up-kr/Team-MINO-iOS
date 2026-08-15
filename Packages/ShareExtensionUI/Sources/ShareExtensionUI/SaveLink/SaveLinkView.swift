import Core
import DesignSystem
import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — Store 는 .task 에서 1회 lazy 생성

/// 공유받은 링크를 방에 저장하는 바텀시트. Figma `013-1 외부 공유 시 바텀시트`(node 2661:164102 외).
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
                        SaveLinkContent(
                            rooms: store.state.rooms,
                            checkedRoomIDs: store.state.checkedRoomIDs,
                            savedRoomIDs: store.state.savedRoomIDs,
                            canSubmit: store.state.canSubmit,
                            safeAreaBottom: proxy.safeAreaInsets.bottom,
                            onToggleRoom: { store.send(.toggleRoom($0)) },
                            onSave: { store.send(.tapSave) }
                        )
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

    /// 저장이 끝나면 시트는 사라지고 스낵바만 남는다. Figma `013-2`(화면 바닥에서 40).
    private var savedFeedback: some View {
        MHSnackbar(title: "저장이 완료됐습니다.", icon: .check)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .accessibilityIdentifier("SaveLink.completionSnackbar")
    }
}

/// 값과 콜백만 받는 마크업. Store 를 모른다.
struct SaveLinkContent: View {
    let rooms: [SharedRoom]
    let checkedRoomIDs: Set<String>
    let savedRoomIDs: Set<String>
    let canSubmit: Bool
    let safeAreaBottom: CGFloat
    let onToggleRoom: (String) -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            grabber
            header
            roomList
            // safeArea: false — 시트가 자기 바닥을 홈 인디케이터까지 늘려 이미 여백을 확보한다.
            MHActionArea(main: .init("저장하기", isEnabled: canSubmit, action: onSave), safeArea: false)
                .padding(.bottom, safeAreaBottom)
        }
        .frame(height: SaveLinkSheetMetrics.height(roomCount: rooms.count, safeAreaBottom: safeAreaBottom),
               alignment: .top)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .fill(Color.mhBackgroundElevatedNormal)
        }
        .accessibilityIdentifier("SaveLink.sheet")
    }

    private var grabber: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.mhFillNormal)
            .frame(width: 38, height: 4)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .accessibilityHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("게시물 저장")
                .mhTypography(.heading2Bold)
                .foregroundStyle(Color.mhLabelNormal)
            Text("장소를 저장할 방을 선택해주세요.")
                .mhTypography(.label1NormalRegular)
                .foregroundStyle(Color.mhLabelNeutral)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("SaveLink.header")
    }

    private var roomList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(rooms) { room in
                    MHRoomCard(
                        title: room.name,
                        memo: room.memo,
                        placeCount: room.placeCount,
                        selection: Binding(
                            get: { checkedRoomIDs.contains(room.id) },
                            set: { _ in onToggleRoom(room.id) }
                        )
                    )
                    .padding(.horizontal, 20)
                    // 체크박스는 18pt 라 겨냥이 어렵다 — 줄 전체를 탭 영역으로 넓힌다.
                    .contentShape(Rectangle())
                    .onTapGesture { onToggleRoom(room.id) }
                    // 이미 저장된 방은 체크된 채 비활성(MHCheckbox 가 isEnabled 를 읽어 흐려진다).
                    // 줄 탭보다 **바깥**에 걸어야 넓힌 탭 영역까지 함께 죽는다.
                    .disabled(savedRoomIDs.contains(room.id))
                    .accessibilityIdentifier("SaveLink.room.\(room.id)")
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: .infinity)
    }
}

#Preview("방 5개 — 644") {
    ZStack(alignment: .bottom) {
        // 실제로는 호스트 화면이 비친다 — 시트 경계를 보려고 깔아둔 배경.
        Color.mhMaterialDimmer.ignoresSafeArea()
        SaveLinkContent(
            rooms: SharedRoom.samples,
            checkedRoomIDs: ["2"],
            savedRoomIDs: ["2"],
            canSubmit: false,
            safeAreaBottom: 34,
            onToggleRoom: { _ in },
            onSave: {}
        )
    }
}
