import Domain
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
}
