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
            onOpenMap: openMap,
            onOpenSource: {},
            onShare: { store.send(.tapShare) },
            onClose: { store.send(.tapClose) }
        )
    }

    private var content: some View {
        MHBottomSheetScrollView(onOffsetChange: updateHeaderCollapse) {
            VStack(spacing: 0) {
                PlaceDetailPhotoCarousel(count: place.photoCount)
                divider
                PlaceDetailCommentSection(
                    comments: store.state.comments,
                    draft: $draft,
                    onSubmit: submitComment
                )
            }
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
}

private final class CollapseRef {
    var isCollapsed = false
}

#Preview("장소 상세 시트") {
    let store = PlaceDetailStore(
        PlaceDetailState(place: .sample, comments: Comment.samples),
        reduce: { _, _ in .none }
    )
    return ZStack {
        Color.mhFillAlternative.ignoresSafeArea()
        PlaceDetailView(store: store, detent: .full)
    }
}
