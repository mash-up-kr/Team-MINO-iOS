import DesignSystem
import FlowCoordination
import SwiftUI

/// 마이 탭 진입 View. 실제 화면이 붙기 전까지 탭 이름과 방 상세 시트 확인용 버튼만 표시한다.
public struct ProfileTabView: View {
    private let coordinator: ProfileCoordinator

    public init(coordinator: ProfileCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            ZStack {
                VStack(spacing: 16) {
                    Text("마이")
                        .accessibilityIdentifier("ProfileTab.title")

                    MHButton("방 상세 열기", size: .medium) {
                        coordinator.isRoomDetailPresented = true
                    }
                    .accessibilityIdentifier("ProfileTab.openRoomDetail")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // MHBottomSheet 은 딤 없는 비모달이라 .sheet 가 아니라 ZStack 에 겹쳐 놓는다
                if coordinator.isRoomDetailPresented {
                    RoomDetailSheet(room: .sample, locations: RoomDetailLocation.samples) {
                        coordinator.isRoomDetailPresented = false
                    }
                    .transition(.move(edge: .bottom))
                }
            }
            .animation(.spring(duration: 0.3), value: coordinator.isRoomDetailPresented)
        }
    }
}

#Preview {
    ProfileTabView(coordinator: ProfileCoordinator())
}
