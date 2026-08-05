import DesignSystem
import SwiftUI

/// 리스트형 카드 — `MHLocationCard(layout: .compact)` 래핑. Figma `Card_Location A`.
struct LocationCompactCard: View {
    let location: RoomDetailLocation
    let onMore: () -> Void

    var body: some View {
        MHLocationCard(
            title: location.name,
            address: location.address,
            commentCount: location.commentCount,
            members: [nil],
            layout: .compact,
            moreButtonLabel: "\(location.name) 더보기",
            onMore: onMore
        )
    }
}

#Preview {
    LocationCompactCard(location: RoomDetailLocation.samples[0]) {}
        .padding(.horizontal, 20)
}
