import FlowCoordination
import SwiftUI

/// 마이 탭 진입 View. 실제 화면이 붙기 전까지 탭 이름만 표시한다.
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
