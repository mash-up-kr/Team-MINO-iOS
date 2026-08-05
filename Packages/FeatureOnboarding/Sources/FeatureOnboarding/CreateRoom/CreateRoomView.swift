import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — Store 는 .task 에서 1회 lazy 생성
// (body 평가 중 Coordinator 의 Store 캐시를 변이하지 않도록)
struct CreateRoomView: View {
    private let coordinator: OnboardingCoordinator
    @State private var store: CreateRoomStore?
    // 뒤로가기: Coordinator.pop() 을 직접 부르지 않고 NavigationStack 표준 dismiss 를 쓴다.
    @Environment(\.dismiss) private var dismiss

    init(coordinator: OnboardingCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        Group {
            if let store {
                CreateRoomContent(
                    roomName: Binding(
                        get: { store.state.roomName },
                        set: { store.send(.roomNameChanged($0)) }
                    ),
                    roomDescription: Binding(
                        get: { store.state.roomDescription },
                        set: { store.send(.roomDescriptionChanged($0)) }
                    ),
                    selectedColorIndex: store.state.selectedColorIndex,
                    isCreateEnabled: store.state.isCreateEnabled,
                    onSelectColor: { store.send(.selectColor($0)) },
                    onCreate: { store.send(.tapNext) },
                    onBack: { dismiss() },
                    onSkip: { store.send(.tapSkip) }
                )
            } else {
                ProgressView()
                    .task { store = coordinator.makeCreateRoomStore() }
            }
        }
        // 마크업이 자체 상단 내비바를 그린다 — 시스템 내비바를 두면 뒤로가기가 두 개로 보인다.
        .toolbar(.hidden, for: .navigationBar)
    }
}
