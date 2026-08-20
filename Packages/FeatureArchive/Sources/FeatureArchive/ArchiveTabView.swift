import FlowCoordination
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
        }
    }
}
