import DesignSystem
import FlowCoordination
import RoomCreationUI
import SwiftUI

/// 홈 탭 진입 View. NavigationStack 을 Coordinator 에 바인딩한다.
///
/// 저장 완료 스낵바는 NavigationStack **바깥**의 ZStack 에 둔다.
/// NavigationStack 은 상위(MainTabView)의 `safeAreaInset` 탭바 인셋을 자기 콘텐츠엔 전파하지 않고
/// 기기 홈 인디케이터 인셋만 적용한다 — 그래서 스택 안(HomeContentView)에 두면 탭바에 가린다.
/// 스택 바깥의 이 ZStack 은 탭바만큼 줄어든 safe area 를 그대로 보므로 탭바 위에 뜬다.
public struct HomeTabView: View {
    private let coordinator: HomeCoordinator
    @State private var store: HomeStore?

    public init(coordinator: HomeCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        ZStack(alignment: .bottom) {
            NavigationStack(path: $coordinator.path) {
                content
                    .navigationDestination(for: HomeRoute.self) { route in
                        switch route {
                        case .createRoom:
                            // 방 리스트 시트에서 진입 → 건너뛰기 없음(showsSkip: false)
                            // RoomFormView 가 내비바를 숨겨 엣지 백스와이프가 꺼지므로 되살린다.
                            RoomFormView(makeStore: coordinator.makeRoomFormStore, showsSkip: false)
                                .enablesBackSwipe()
                        }
                    }
            }
            savedToast
        }
        .animation(.easeInOut(duration: 0.2), value: store?.state.savedToastID)
    }

    /// 저장 완료 스낵바 (Figma `013-2`). 위 주석과 같은 이유로 NavigationStack **바깥**에 둔다 —
    /// 안에 두면 탭바에 가린다. 노출 2초 뒤 스스로 사라진다.
    @ViewBuilder
    private var savedToast: some View {
        if let store, let toastID = store.state.savedToastID {
            MHSnackbar(title: "저장이 완료됐습니다.", icon: .checkThick)
                .padding(.horizontal, 20)
                // 시안(013-2, node 2862:178010)의 "화면 바닥에서 40" 을 탭바 위로 옮긴 값 —
                // 시안 프레임에는 탭바가 없어 그대로 40 을 주면 탭바에 겹친다.
                .padding(.bottom, 40)
                .allowsHitTesting(false)   // 장식 — 뒤의 카드 덱 스와이프를 가리지 않는다
                .transition(.opacity)
                .accessibilityIdentifier("Home.savedToast")
                .task(id: toastID) {
                    // 취소를 삼키면 안 된다. try? 로 받으면 새 토스트가 이 task 를 취소했을 때
                    // sleep 이 즉시 반환하고, 이어지는 dismiss 가 **방금 뜬 토스트**를 지운다.
                    do { try await Task.sleep(for: .seconds(2)) } catch { return }
                    store.send(.dismissSavedToast(toastID))
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let store {
            HomeContentView(store: store)
        } else {
            ProgressView()
                .task { store = coordinator.makeHomeStore() }
        }
    }
}
