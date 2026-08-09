import DesignSystem
import SwiftUI

/// 리스트형 카드 — `MHLocationCard(layout: .compact)` 래핑. Figma `Card_Location A`.
struct LocationCompactCard: View {
    let location: RoomDetailLocation
    var menuItems: [MHMenuItem] = []
    var menuPlacement: MHLocationCardMenuPlacement = .below
    var menuPresented: Binding<Bool>?

    var body: some View {
        MHLocationCard(
            title: location.name,
            address: location.address,
            commentCount: location.commentCount,
            members: [nil],
            layout: .compact,
            menuItems: menuItems,
            menuPlacement: menuPlacement,
            menuPresented: menuPresented,
            moreButtonLabel: "\(location.name) 더보기"
        )
    }
}

#Preview {
    LocationCompactCard(location: RoomDetailLocation.samples[0])
        .padding(.horizontal, 20)
}
