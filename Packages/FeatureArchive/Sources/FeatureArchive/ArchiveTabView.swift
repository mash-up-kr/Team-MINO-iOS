import FlowCoordination
import SwiftUI

/// 저장 탭 진입 View. 지도·필터바·바텀시트 껍데기(``ArchiveShellView``)를 띄운다.
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
