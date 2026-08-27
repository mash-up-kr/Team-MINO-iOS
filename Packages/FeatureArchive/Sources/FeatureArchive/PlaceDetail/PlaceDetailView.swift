import DesignSystem
import Domain
import MVI
import SwiftUI

struct PlaceDetailView: View {
    let store: PlaceDetailStore
    let detent: MHBottomSheetDetent

    @State private var draft = ""
    @State private var isScrolledPastHeader = false
    @State private var collapseRef = CollapseRef()
    @Environment(\.openURL) private var openURL

    private static let collapseOffset: CGFloat = 40
    private static let expandOffset: CGFloat = 8

    private var place: PlaceDetailPlace { store.state.place }
    private var isHeaderCollapsed: Bool { detent == .full && isScrolledPastHeader }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .onChange(of: detent) { _, newValue in
            guard newValue != .full else { return }
            collapseRef.isCollapsed = false
            isScrolledPastHeader = false
        }
    }

    private var header: some View {
        PlaceDetailHeader(
            place: place,
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
                    draft: $draft,
                    canSubmit: store.state.canSubmitComment,
                    onSubmit: submitComment
                )
            }
        }
        // 스토어 인스턴스가 곧 "지금 보고 있는 핀" 이다 — 다른 핀을 고르면 Coordinator 가 새로 만들어
        // 주므로, id 로 걸어 두면 같은 자리에 뷰가 재사용돼도 출처를 다시 읽는다.
        .task(id: ObjectIdentifier(store)) {
            store.send(.load)
            store.send(.loadCurrentMember)
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
        draft = ""
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
            comments: PlaceDetailComment.samples,
            currentMember: MemberProfile(id: MemberID("user-0001"), nickname: "나", avatarID: 1)
        ),
        reduce: { _, _ in .none }
    )
    return ZStack {
        Color.mhFillAlternative.ignoresSafeArea()
        PlaceDetailView(store: store, detent: .full)
    }
}
