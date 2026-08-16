import DesignSystem
import MVI
import SwiftUI

struct PlaceDetailView: View {
    let store: PlaceDetailStore
    let detent: MHBottomSheetDetent

    @State private var draft = ""
    @State private var isScrolledPastHeader = false
    @Environment(\.openURL) private var openURL

    /// 접기 시작·펴기 임계값을 벌려, 경계에서 스크롤이 미세하게 흔들려도 헤더가 깜박이지 않게 한다.
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
            if newValue != .full { isScrolledPastHeader = false }
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
        if !isScrolledPastHeader, offset > Self.collapseOffset {
            isScrolledPastHeader = true
        } else if isScrolledPastHeader, offset < Self.expandOffset {
            isScrolledPastHeader = false
        }
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

#Preview("장소 상세 시트") {
    let store = PlaceDetailStore(
        PlaceDetailState(place: .sample, comments: PlaceDetailComment.samples),
        reduce: { _, _ in .none }
    )
    return ZStack {
        Color.mhFillAlternative.ignoresSafeArea()
        PlaceDetailView(store: store, detent: .full)
    }
}
