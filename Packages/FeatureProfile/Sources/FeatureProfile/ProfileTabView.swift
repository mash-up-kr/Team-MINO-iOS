import FlowCoordination
import SwiftUI

public struct ProfileTabView: View {
    private let coordinator: ProfileCoordinator

    public init(coordinator: ProfileCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            Text("마이")
                .accessibilityIdentifier("ProfileTab.title")
        }
    }
}

#Preview {
    ProfileTabView(coordinator: ProfileCoordinator())
}
