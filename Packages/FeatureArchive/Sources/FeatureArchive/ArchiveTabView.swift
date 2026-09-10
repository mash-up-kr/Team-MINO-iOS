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
                    case .editRoom:
                        editRoom
                    }
                }
        }
    }

    /// 방 편집(004-5) — 만들기와 같은 화면의 편집 모드.
    ///
    /// 고칠 방이 없으면(진입점이 경로를 걷어 간 뒤 이 화면이 한 프레임 더 그려지는 경우)
    /// 빈 화면을 두고 곧장 pop 한다. 만들기로 떨어뜨리면 "방 편집" 제목 아래 빈 폼이 떠서
    /// 저장이 **새 방을 만들어** 버린다.
    @ViewBuilder private var editRoom: some View {
        if let room = coordinator.editingRoom {
            RoomFormView(makeStore: { coordinator.makeEditRoomStore(room: room) }, showsSkip: false)
        } else {
            Color.clear.onAppear { coordinator.pop() }
        }
    }
}
