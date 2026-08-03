import DesignSystem
import SwiftUI

/// 카드형 카드 — `MHLocationCard(layout: .expanded)` 래핑. Figma `Card_Location B`.
struct LocationGridCard: View {
    let location: RoomDetailLocation
    let onMore: () -> Void

    var body: some View {
        MHLocationCard(
            title: location.name,
            address: location.address,
            commentCount: Int(location.commentCount) ?? 0,
            members: [nil],
            layout: .expanded,
            onMore: onMore
        )
    }
}

#Preview {
    LocationGridCard(location: RoomDetailLocation.samples[0]) {}
        .padding(.horizontal, 20)
}
