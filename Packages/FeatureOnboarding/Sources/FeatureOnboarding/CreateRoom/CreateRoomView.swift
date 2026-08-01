import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — Store 는 .task 에서 1회 lazy 생성
// (body 평가 중 Coordinator 의 Store 캐시를 변이하지 않도록)
struct CreateRoomView: View {
    private let coordinator: OnboardingCoordinator
    @State private var store: CreateRoomStore?

    init(coordinator: OnboardingCoordinator) {
        self.coordinator = coordinator
    }

    var body: some View {
        Group {
            if let store {
                VStack(spacing: 16) {
                    Text("공동방 만들기")
                    Button("다음") { store.send(.tapNext) }
                        .accessibilityIdentifier("Onboarding.createRoom.next")
                }
            } else {
                ProgressView()
                    .task { store = coordinator.makeCreateRoomStore() }
            }
        }
    }
}
