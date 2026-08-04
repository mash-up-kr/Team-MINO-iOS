import DesignSystem
import SwiftUI

/// 카드형 카드 — `MHLocationCard(layout: .expanded)` 래핑. Figma `Card_Location B`.
struct LocationExpandedCard: View {
    let location: RoomDetailLocation
    let onMore: () -> Void

    var body: some View {
        MHLocationCard(
            thumbnails: Array(repeating: nil, count: max(location.photoCount, 1)),
            title: location.name,
            address: location.address,
            commentCount: location.commentCount,
            members: [nil],
            layout: .expanded,
            moreButtonLabel: "\(location.name) 더보기",
            onMore: onMore
        )
    }
}

#Preview {
    LocationExpandedCard(location: RoomDetailLocation.samples[0]) {}
        .padding(.horizontal, 20)
}
