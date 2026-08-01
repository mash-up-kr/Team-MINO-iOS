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
        // TODO [AI_IMPL]: store 있으면 placeholder 본문 — 화면명 Text·"다음" 버튼(store.send(.tapNext)),
        //   accessibilityIdentifier "Onboarding.createRoom.next"
        //   없으면 ProgressView().task { store = coordinator.makeCreateRoomStore() }
        fatalError("not implemented")
    }
}
