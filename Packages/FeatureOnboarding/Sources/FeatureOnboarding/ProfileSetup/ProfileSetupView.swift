import ProfileSetupUI
import RoomCreationUI
import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 진입 화면 View가 NavigationStack 보유, Coordinator는 생성자 주입
//
// 화면 자체(`ProfileSetupScreen`)는 ProfileSetupUI 에 있다 — 마이페이지도 같은 화면을 쓰기 때문이다.
// 여기 남은 것은 온보딩 flow 의 스택 소유와 라우팅뿐이다.
public struct ProfileSetupView: View {
    private let coordinator: OnboardingCoordinator

    public init(coordinator: OnboardingCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            // 온보딩 최초 진입이라 돌아갈 곳이 없다 — 뒤로가기를 그리지 않는다.
            ProfileSetupScreen(makeStore: coordinator.makeProfileSetupStore)
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .createRoom:
                        // 온보딩엔 돌아갈 곳이 없어 뒤로가기를 숨긴다(디자인 ⑦). 대신 건너뛰기가 있다(⑥).
                        RoomFormView(makeStore: coordinator.makeRoomFormStore, showsBack: false)
                    case .inviteFriends:
                        InviteFriendsView(makeStore: coordinator.makeInviteFriendsStore)
                    case .tutorial:
                        TutorialView(makeStore: coordinator.makeTutorialStore)
                    }
                }
        }
    }
}
