import DesignSystem
import SwiftUI

/// 리스트형 카드 — `MHLocationCard(layout: .compact)` 래핑. Figma `Card_Location A`.
struct LocationRowCard: View {
    let location: RoomDetailLocation
    let onMore: () -> Void

    var body: some View {
        MHLocationCard(
            title: location.name,
            address: location.address,
            commentCount: Int(location.commentCount) ?? 0,
            members: [nil],
            layout: .compact,
            onMore: onMore
        )
    }
}

#Preview {
    LocationRowCard(location: RoomDetailLocation.samples[0]) {}
        .padding(.horizontal, 20)
}
