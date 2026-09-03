import Domain
import Foundation
import Testing
@testable import FeatureNotification

@MainActor
struct NotificationCoordinatorTests {
    private struct StubFetchNotifications: FetchNotificationsUseCase {
        func execute() async throws -> Page<AppNotification> {
            Page(items: [], page: 0, pageSize: 20, hasNext: false)
        }
        func execute(next request: PageRequest) async throws -> Page<AppNotification> {
            Page(items: [], page: request.page, pageSize: request.pageSize, hasNext: false)
        }
    }

    private struct StubDeps: NotificationDeps {
        var fetchNotifications: FetchNotificationsUseCase = StubFetchNotifications()
        var fetchPinDetail: FetchPinDetailUseCase = StubOpenDestination()
        var fetchRoom: FetchRoomUseCase = StubOpenDestination()
    }

    @Test("생성 직후 내비게이션 스택은 비어 있다")
    func startsWithEmptyPath() {
        #expect(NotificationCoordinator(deps: StubDeps()).path.isEmpty)
    }

    @Test("pushSaveError 는 저장 오류 안내 화면을 push 한다")
    func handlePushSaveError_pushes() {
        let coordinator = NotificationCoordinator(deps: StubDeps())
        coordinator.handle(.pushSaveError)
        #expect(coordinator.path == [.saveError])
    }

    // 탭 밖 이동은 알림 탭 스택을 건드리면 안 된다 — 건드리면 저장 탭으로 넘어간 뒤에도
    // 알림 탭에 화면이 쌓인 채 남는다.
    @Test("탭 밖 이동은 스택을 건드리지 않고 콜백으로 넘긴다")
    func handleCrossTab_delegatesWithoutPushing() {
        let coordinator = NotificationCoordinator(deps: StubDeps())
        var received: [NotificationCrossTabDestination] = []
        coordinator.onCrossTab = { received.append($0) }

        coordinator.handle(.openCrossTab(.place(pin: NotificationFixture.pin, room: NotificationFixture.room)))
        coordinator.handle(.openCrossTab(.room(NotificationFixture.room)))

        #expect(coordinator.path.isEmpty)
        #expect(received == [.place(pin: NotificationFixture.pin, room: NotificationFixture.room), .room(NotificationFixture.room)])
    }

    // 콜백은 컴포지션 루트가 주입한다. 빠뜨려도 크래시하지 않고 이동만 안 되어야 한다.
    @Test("콜백이 배선되지 않아도 크래시하지 않는다")
    func handleCrossTab_withoutCallbackIsSafe() {
        let coordinator = NotificationCoordinator(deps: StubDeps())

        coordinator.handle(.openCrossTab(.room(NotificationFixture.room)))

        #expect(coordinator.path.isEmpty)
    }
}
