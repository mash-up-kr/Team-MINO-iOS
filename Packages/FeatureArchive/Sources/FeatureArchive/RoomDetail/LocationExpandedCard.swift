import DesignSystem
import SwiftUI

/// 카드형 카드 — `MHLocationCard(layout: .expanded)` 래핑. Figma `Card_Location B`.
struct LocationExpandedCard: View {
    let location: RoomDetailLocation
    var menuItems: [MHMenuItem] = []
    var menuPlacement: MHLocationCardMenuPlacement = .below
    var menuPresented: Binding<Bool>?

    var body: some View {
        MHLocationCard(
            thumbnails: Array(repeating: nil, count: max(location.photoCount, 1)),
            title: location.name,
            address: location.address,
            commentCount: location.commentCount,
            members: ArchiveAvatarArt.images(for: location.saver),
            layout: .expanded,
            menuItems: menuItems,
            menuPlacement: menuPlacement,
            menuPresented: menuPresented,
            moreButtonLabel: "\(location.name) 더보기"
        )
    }
}

#Preview {
    LocationExpandedCard(location: RoomDetailLocation.samples[0])
        .padding(.horizontal, 20)
}
