import DesignSystem
import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — Store 는 .task 에서 1회 lazy 생성.
// Coordinator 대신 `makeStore` 클로저를 받는 이유는 RoomFormView 주석 참조.

/// 방 상세 헤더의 `+` 로 여는 친구 초대 바텀시트. Figma `2542:125843`(`004-4-2_친구 초대 클릭`).
///
/// 시안이 딤(`Material/Dimmer`)을 동반한 모달이라 ``MHBottomSheet``(딤 없는 비모달 3-detent)이 아니라
/// SwiftUI 네이티브 `.sheet` 위에 얹는다 — ``RoomShareUI.RoomShareSheet`` 와 같은 판단.
/// 띄우는 쪽은 `FeatureArchive.ArchiveShellView`.
///
/// 온보딩의 ``InviteFriendsView``(009-1 풀스크린)와 **같은 Store 를 쓰고 마크업만 다르다** — 초대·복사
/// 로직은 진입점과 무관하고, 시안이 다른 건 껍데기(참여자 목록·방 정보 헤더)뿐이다.
public struct RoomInviteSheetView: View {
    private let roomName: String
    private let thumbnail: MHRoomThumbnailKind
    private let members: [RoomInviteMember]
    private let makeStore: @MainActor () -> InviteFriendsStore
    private let onClose: () -> Void

    @State private var store: InviteFriendsStore?

    public init(
        roomName: String,
        thumbnail: MHRoomThumbnailKind,
        members: [RoomInviteMember],
        makeStore: @escaping @MainActor () -> InviteFriendsStore,
        onClose: @escaping () -> Void
    ) {
        self.roomName = roomName
        self.thumbnail = thumbnail
        self.members = members
        self.makeStore = makeStore
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            grabber
            header
            content
        }
        .background(.mhBackgroundElevatedNormal)
        .accessibilityIdentifier("RoomInvite.sheet")
        // 시트 높이는 내용이 고정폭이라 시안 값 하나로 끝난다(방 개수로 갈리는 ``RoomShareSheet`` 와 달리
        // 참여자 목록이 상한 높이를 넘지 않는다). 나머지 presentation 설정은 띄우는 쪽이 준다.
        .presentationDetents([.height(RoomInviteSheetMetrics.detentHeight)])
    }

    // 그래버 — h30(py12) 안에 38×4 바. 시스템 인디케이터는 띄우는 쪽이 껐다.
    private var grabber: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.mhFillNormal)
            .frame(width: 38, height: 4)
            .frame(height: 30)
    }

    // 방 정보 + 닫기 (①②) — 썸네일 46 + 방 이름 + 원형 X.
    private var header: some View {
        HStack(spacing: 12) {
            MHRoomThumbnail(kind: thumbnail, size: 46)
            Text(roomName)
                .mhTypography(.body1NormalBold)
                .foregroundStyle(Color.mhLabelNormal)
                .lineLimit(1)
            Spacer(minLength: 8)
            MHCircleIconButton(icon: .close, accessibilityLabel: "닫기", action: onClose)
                .accessibilityIdentifier("RoomInvite.close")
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }

    /// 참여자 목록·버튼은 Store 가 생긴 뒤에 그린다. 그래버·헤더(닫기)는 바깥에 둬서 생성 전에도
    /// 시트를 닫을 수 있다(``RoomShareSheet`` 와 같은 구성).
    @ViewBuilder private var content: some View {
        if let store {
            RoomInviteSheetContent(members: members, state: store.state, send: store.send)
                // 공유 시트는 이 시트 **안**에 붙인다 — 바깥(껍데기)에 붙이면 이 시트가 위를 덮어
                // 안 보이고, 이 시트를 닫고 띄우면 돌아올 자리가 없다.
                .sheet(item: sharingLink(store)) { ShareSheet(url: $0.url) }
                // 안내는 잠깐 띄웠다 거둔다. id 를 걸어 새 안내가 오면 타이머가 다시 시작된다.
                .task(id: store.state.notice) {
                    guard store.state.notice != nil else { return }
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    store.send(.dismissNotice)
                }
        } else {
            // Store 는 여기서 1회 생성한다 — `makeStore` 가 @MainActor 라 View.init 에서는 못 부른다.
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { store = makeStore() }
        }
    }

    /// 시트는 사용자가 스와이프로도 닫으므로 닫힘을 Store 에 되돌려준다 — 안 그러면 링크가 state 에
    /// 남아 시트가 다시 뜬다(``InviteFriendsView`` 와 같은 이유).
    private func sharingLink(_ store: InviteFriendsStore) -> Binding<SharedInviteLink?> {
        Binding(
            get: { store.state.sharingLink },
            set: { if $0 == nil { store.send(.dismissShareSheet) } }
        )
    }
}
