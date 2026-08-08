import DesignSystem
import FlowCoordination
import SwiftUI

/// 마이 탭 진입 View. 실제 화면이 붙기 전까지 탭 이름과 방 상세 시트 확인용 버튼만 표시한다.
public struct ProfileTabView: View {
    private let coordinator: ProfileCoordinator

    /// 공유 시트를 띄운 장소. 방 상세 시트는 `MHBottomSheet` 클립 경계 안이라 딤 모달을 자기 안에서 못 띄운다.
    @State private var sharingLocation: RoomDetailLocation?

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
                    RoomDetailSheet(
                        room: .sample,
                        locations: RoomDetailLocation.samples,
                        onOutput: handle
                    )
                    .transition(.move(edge: .bottom))
                }
            }
            .animation(.spring(duration: 0.3), value: coordinator.isRoomDetailPresented)
            .sheet(item: $sharingLocation) { location in
                RoomShareSheet(
                    location: location,
                    rooms: RoomShareRoom.samples,
                    onClose: { sharingLocation = nil },
                    onSubmit: { _ in sharingLocation = nil }
                )
                .presentationDetents([.height(RoomShareSheet.detentHeight)])
                .presentationCornerRadius(20)
                .presentationDragIndicator(.hidden)   // 그래버는 시안대로 시트 안에서 직접 그린다
                .presentationBackground(.mhBackgroundElevatedNormal)
            }
        }
    }

    private func handle(_ output: RoomDetailOutput) {
        switch output {
        case .close:
            coordinator.isRoomDetailPresented = false
        case .shareLocation(let id):
            sharingLocation = RoomDetailLocation.samples.first { $0.id == id }
        }
    }
}

#Preview {
    ProfileTabView(coordinator: ProfileCoordinator())
}
