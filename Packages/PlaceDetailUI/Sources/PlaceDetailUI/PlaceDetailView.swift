import DesignSystem
import Domain
import MVI
import SwiftUI

public struct PlaceDetailView: View {
    private let store: PlaceDetailStore
    /// 상단 여백이 시트 단계마다 다르다 — ``PlaceDetailHeaderMetrics`` 참조. 바텀시트 밖에서
    /// 띄우는 진입점은 `.full` 을 넘긴다.
    private let detent: MHBottomSheetDetent

    public init(store: PlaceDetailStore, detent: MHBottomSheetDetent) {
        self.store = store
        self.detent = detent
    }

    @State private var draft = ""
    @State private var isScrolledPastHeader = false
    @State private var collapseRef = CollapseRef()
    @Environment(\.openURL) private var openURL

    private static let collapseOffset: CGFloat = 40
    private static let expandOffset: CGFloat = 8

    private var place: PlaceDetailPlace { store.state.place }
    private var isHeaderCollapsed: Bool { detent == .full && isScrolledPastHeader }

    public var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .onChange(of: detent) { _, newValue in
            guard newValue != .full else { return }
            collapseRef.isCollapsed = false
            isScrolledPastHeader = false
        }
        // ⑭ "클릭 시 삭제하기 모달이 활성화된다". 코멘트 삭제 전용 시안이 없어 같은 앱의 장소
        // 삭제 모달(004-1-3-1 `3222:87768`)을 준용한다 — 제목 "이 …를 삭제할까요?" + 되돌릴 수
        // 없다는 한 줄 + 취소/삭제 두 버튼이 이 앱 확인 모달의 공통 꼴이다(004-2-2 방 나가기도 같다).
        .mhDialog(item: store.state.commentDeletion) { deletion in
            MHDialog(
                title: "이 댓글을 삭제할까요?",
                message: "삭제한 댓글은 다시 되돌릴 수 없어요.",
                cancel: MHAction("취소", isEnabled: !deletion.isSubmitting) {
                    store.send(.cancelDeleteComment)
                },
                confirm: MHAction("삭제", isEnabled: !deletion.isSubmitting) {
                    store.send(.confirmDeleteComment)
                }
            )
        }
    }

    private var header: some View {
        PlaceDetailHeader(
            place: place,
            detent: detent,
            isCollapsed: isHeaderCollapsed,
            canOpenSource: store.state.sourceURL != nil,
            onOpenMap: openMap,
            onOpenSource: openSource,
            onShare: { store.send(.tapShare) },
            onClose: { store.send(.tapClose) }
        )
    }

    private var content: some View {
        MHBottomSheetScrollView(onOffsetChange: updateHeaderCollapse) {
            VStack(spacing: 0) {
                // 사진이 없으면 캐러셀을 통째로 빼고 구분선만 남긴다 — 헤더와 코멘트 사이의
                // 경계는 그대로 필요하다.
                if !place.photos.isEmpty {
                    PlaceDetailPhotoCarousel(photos: place.photos)
                }
                divider
                PlaceDetailCommentSection(
                    comments: store.state.comments,
                    showsEmptyState: store.state.showsCommentEmptyState,
                    menuCommentID: store.state.menuCommentID,
                    canDelete: store.state.canDelete,
                    draft: $draft,
                    canSubmit: store.state.canSubmitComment,
                    onToggleMenu: toggleCommentMenu,
                    onRequestDelete: { store.send(.tapDeleteComment($0)) },
                    onSubmit: submitComment
                )
            }
        }
        // 스토어 인스턴스가 곧 "지금 보고 있는 핀" 이다 — 다른 핀을 고르면 Coordinator 가 새로 만들어
        // 주므로, id 로 걸어 두면 같은 자리에 뷰가 재사용돼도 출처를 다시 읽는다.
        .task(id: ObjectIdentifier(store)) {
            store.send(.load)
            store.send(.loadComments)
            store.send(.loadCurrentMember)
            // 저장된 방은 지도 위 버튼(005-1 ⑮)이 쓰는 값이지만 같은 Store 라 여기서 함께 부른다 —
            // 버튼은 시트 밖(껍데기)에 있어 스스로 진입 시점을 잡을 자리가 없다.
            store.send(.loadSavedRooms)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(.mhLineNormalNormal)
            .frame(height: 1)
            .frame(height: 12)
    }

    private func updateHeaderCollapse(_ offset: CGFloat) {
        let collapsed = collapseRef.isCollapsed
        let next = collapsed ? offset >= Self.expandOffset : offset > Self.collapseOffset
        guard next != collapsed else { return }
        collapseRef.isCollapsed = next
        withAnimation(.easeInOut(duration: 0.2)) { isScrolledPastHeader = next }
    }

    private func submitComment() {
        store.send(.submitComment(draft))
        // 응답을 기다리지 않고 비운다 — 등록 중에도 다음 글을 칠 수 있어야 하고, 목은 실패하지
        // 않는다. 실 API 가 붙어 실패가 실제로 일어나면 친 글을 되돌려 줘야 한다(리듀서의
        // `.commentPostFailed` 주석 참조).
        draft = ""
    }

    private func toggleCommentMenu(_ id: PinCommentID?) {
        store.send(id.map { .tapCommentMenu($0) } ?? .dismissCommentMenu)
    }

    private func openMap() {
        guard let url = PlaceDetailExternalMap.url(forAddress: place.address) else { return }
        openURL(url)
    }

    private func openSource() {
        guard let url = store.state.sourceURL else { return }
        openURL(url)
    }
}

private final class CollapseRef {
    var isCollapsed = false
}

#Preview("장소 상세 시트") {
    let store = PlaceDetailStore(
        PlaceDetailState(
            place: .sample,
            comments: PinComment.placeDetailSamples,
            // 표본 중 `c2` 의 작성자 — 이 한 줄에만 삭제 케밥이 붙는다.
            currentMember: MemberProfile(id: MemberID("user-0001"), nickname: "나", avatarColor: .red)
        ),
        reduce: { _, _ in .none }
    )
    return ZStack {
        Color.mhFillAlternative.ignoresSafeArea()
        PlaceDetailView(store: store, detent: .full)
    }
}
