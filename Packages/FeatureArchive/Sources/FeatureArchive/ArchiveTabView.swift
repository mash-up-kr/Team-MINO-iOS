import FlowCoordination
import SwiftUI

/// 저장 탭 진입 View. 실제 화면이 붙기 전까지 탭 이름만 표시한다.
public struct ArchiveTabView: View {
    private let coordinator: ArchiveCoordinator

    public init(coordinator: ArchiveCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            Text("저장")
                .accessibilityIdentifier("ArchiveTab.title")
        }
    }
}
