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

    private struct StubOpenDestination: FetchPinDetailUseCase, FetchRoomUseCase {
        func execute(pinID: PinID) async throws -> PinDetail { throw DomainError.pinsFetchFailed }
        func execute(id: String) async throws -> Room { throw DomainError.roomsFetchFailed }
    }

    private struct StubDeps: NotificationDeps {
        var fetchNotifications: FetchNotificationsUseCase = StubFetchNotifications()
        var fetchPinDetail: FetchPinDetailUseCase = StubOpenDestination()
        var fetchRoom: FetchRoomUseCase = StubOpenDestination()
    }

    private static let room = Room(
        id: "room-1", type: .shared, name: "맛집 탐방", description: nil, color: .cyan,
        ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
        pinCount: 0, memberCount: 1, users: []
    )

    private static let pin = Pin(
        id: PinID("pin-1"),
        roomID: room.id,
        place: Place(
            id: PlaceID("place-1"), name: "패스트리 순간", address: "서울 성동구",
            coordinate: Coordinate(latitude: 37.5443, longitude: 127.0557)
        ),
        category: .worthVisiting,
        createdAt: Date(timeIntervalSince1970: 0)
    )

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

        coordinator.handle(.openCrossTab(.place(pin: Self.pin, room: Self.room)))
        coordinator.handle(.openCrossTab(.room(Self.room)))

        #expect(coordinator.path.isEmpty)
        #expect(received == [.place(pin: Self.pin, room: Self.room), .room(Self.room)])
    }

    // 콜백은 컴포지션 루트가 주입한다. 빠뜨려도 크래시하지 않고 이동만 안 되어야 한다.
    @Test("콜백이 배선되지 않아도 크래시하지 않는다")
    func handleCrossTab_withoutCallbackIsSafe() {
        let coordinator = NotificationCoordinator(deps: StubDeps())

        coordinator.handle(.openCrossTab(.room(Self.room)))

        #expect(coordinator.path.isEmpty)
    }
}
