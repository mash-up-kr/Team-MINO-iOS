import Core
import DesignSystem
import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — Store 는 .task 에서 1회 lazy 생성

/// 공유받은 링크를 방에 저장하는 바텀시트.
///
/// > **공유 화면 시안이 확정되기 전의 임시 마크업이다.** 흐름을 확인하려고 DS 컴포넌트로 조립해
/// > 뒀을 뿐이라 간격·높이·탭 영역에 디자인 근거가 없다. 시안이 나오면 이 파일을 통째로
/// > 교체한다 — `SaveLinkStore`(State/Action/reducer)와 테스트는 그대로 간다.
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
        ZStack(alignment: .bottom) {
            // 익스텐션 루트는 투명하다 — 바텀시트로 보이게 하려면 딤과 시트를 직접 그려야 한다.
            Color.mhMaterialDimmer
                .ignoresSafeArea()
                .onTapGesture { store?.send(.tapClose) }

            if let store {
                SaveLinkContent(
                    link: store.state.link,
                    rooms: store.state.rooms,
                    selectedRoomIDs: store.state.selectedRoomIDs,
                    canSubmit: store.state.canSubmit,
                    isSaved: store.state.isSaved,
                    onToggleRoom: { store.send(.toggleRoom($0)) },
                    onSave: { store.send(.tapSave) },
                    onClose: { store.send(.tapClose) }
                )
            } else {
                ProgressView()
                    .task { store = makeStore() }
            }
        }
    }
}

/// 값과 콜백만 받는 마크업. Store 를 모른다.
struct SaveLinkContent: View {
    let link: SharedLinkPreview
    let rooms: [SharedRoom]
    let selectedRoomIDs: Set<String>
    let canSubmit: Bool
    let isSaved: Bool
    let onToggleRoom: (String) -> Void
    let onSave: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            grabber
            linkHeader
            divider
            roomList
            // safeArea: false — 시트가 자기 바닥을 홈 인디케이터까지 늘려 이미 여백을 확보한다.
            MHActionArea(main: .init("저장", isEnabled: canSubmit, action: onSave), safeArea: false)
        }
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .fill(Color.mhBackgroundElevatedNormal)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) { completionFeedback }
        .accessibilityIdentifier("SaveLink.sheet")
    }

    private var grabber: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.mhFillNormal)
            .frame(width: 38, height: 4)
            .frame(height: 30)
            .accessibilityHidden(true)
    }

    // MARK: - 링크 미리보기

    private var linkHeader: some View {
        HStack(spacing: 14) {
            linkThumbnail

            VStack(alignment: .leading, spacing: 4) {
                Text(link.title)
                    .mhTypography(.body1NormalBold)
                    .foregroundStyle(Color.mhLabelNormal)
                    .lineLimit(1)
                Text(link.subtitle)
                    .mhTypography(.label2Medium)
                    .foregroundStyle(Color.mhLabelAlternative)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("SaveLink.linkPreview")

            Button(action: onClose) {
                Image(MHIcon.close)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.mhLabelNeutral)
                    .frame(width: 32, height: 32)
                    .background(Color.mhFillNormal, in: Circle())
            }
            .accessibilityLabel("닫기")
            .accessibilityIdentifier("SaveLink.closeButton")
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }

    /// 링크 분석 API 가 붙기 전이라 보여줄 이미지가 없다 — 아이콘 자리표시로 둔다.
    private var linkThumbnail: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.mhFillNormal)
            .frame(width: 46, height: 46)
            .overlay {
                Image(MHIcon.link)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(Color.mhLabelNeutral)
            }
            .accessibilityHidden(true)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.mhLineNormalNormal)
            .frame(height: 1)
            .padding(.horizontal, 20)
            .frame(height: 12)
    }

    // MARK: - 방 목록

    private var roomList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(rooms) { room in
                    MHRoomCard(
                        title: room.name,
                        memo: room.memo,
                        placeCount: room.placeCount,
                        selection: Binding(
                            get: { selectedRoomIDs.contains(room.id) },
                            set: { _ in onToggleRoom(room.id) }
                        )
                    )
                    .padding(.horizontal, 20)
                    .accessibilityIdentifier("SaveLink.room.\(room.id)")
                }
            }
        }
        .frame(maxHeight: 320)
    }

    @ViewBuilder
    private var completionFeedback: some View {
        if isSaved {
            MHSnackbar(title: "저장했어요.")
                .padding(.horizontal, 20)
                .padding(.top, -70)
                .accessibilityIdentifier("SaveLink.completionSnackbar")
        }
    }
}
