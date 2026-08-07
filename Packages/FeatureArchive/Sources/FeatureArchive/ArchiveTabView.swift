import FlowCoordination
import SwiftUI

/// 저장 탭 진입 View. 방 리스트 바텀 시트(``RoomListView``)를 띄운다.
public struct ArchiveTabView: View {
    private let coordinator: ArchiveCoordinator

    public init(coordinator: ArchiveCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            RoomListView()
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}
