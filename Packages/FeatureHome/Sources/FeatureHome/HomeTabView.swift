import FlowCoordination
import SwiftUI

/// 홈 탭 진입 View. 실제 화면이 붙기 전까지 탭 이름만 표시한다.
public struct HomeTabView: View {
    private let coordinator: HomeCoordinator

    public init(coordinator: HomeCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            Text("홈")
                .accessibilityIdentifier("HomeTab.title")
        }
    }
}
