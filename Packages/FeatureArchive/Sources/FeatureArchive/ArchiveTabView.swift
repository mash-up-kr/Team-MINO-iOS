import FlowCoordination
import RoomCreationUI
import SwiftUI

public struct ArchiveTabView: View {
    private let coordinator: ArchiveCoordinator

    public init(coordinator: ArchiveCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            ArchiveShellView(coordinator: coordinator)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: ArchiveRoute.self) { route in
                    switch route {
                    case .createRoom:
                        // 저장 탭에서 진입 → 건너뛰기 없음(showsSkip: false)
                        RoomFormView(makeStore: coordinator.makeRoomFormStore, showsSkip: false)
                    }
                }
        }
    }
}
