import DesignSystem
import ProfileSetupUI
import SwiftUI

/// 리스트형 카드 — `MHLocationCard(layout: .compact)` 래핑. Figma `Card_Location A`.
struct LocationCompactCard: View {
    let location: RoomDetailLocation
    var menuItems: [MHMenuItem] = []
    var menuPlacement: MHLocationCardMenuPlacement = .below
    var menuPresented: Binding<Bool>?

    var body: some View {
        MHLocationCard(
            // 한 칸짜리 썸네일이라 카드가 첫 장만 쓴다(기획 011-1 ② 대표 사진과 같은 규칙).
            imageURLs: location.photos,
            title: location.name,
            address: location.address,
            commentCount: location.commentCount,
            members: AvatarPalette.images(of: location.saver),
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
