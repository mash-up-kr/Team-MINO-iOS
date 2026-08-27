import Core
import Foundation
import Testing
import Domain
import RoomCreationUI
@testable import FeatureArchive

private struct StubFetchRooms: FetchRoomsUseCase {
    func execute() async throws -> [Room] { [] }
}

private struct StubFetchPins: FetchPinsUseCase {
    func execute(rooms: [Room], filter: PinFilter) async throws -> [Pin] { [] }
    func execute(room: Room, page: Int, filter: PinFilter) async throws -> [Pin] { [] }
}


private struct StubArchiveDeps: ArchiveDeps {
    var fetchRooms: FetchRoomsUseCase = StubFetchRooms()
    var fetchPins: FetchPinsUseCase = StubFetchPins()
    var roomCreationPromptSnooze = SnoozeSwitch(
        key: "ArchiveCoordinatorTests.prompt",
        period: .days(14),
        defaults: UserDefaults(suiteName: "ArchiveCoordinatorTests")!
    )
}

private let fixtureRoom = Room(
    id: "r2", type: .shared, name: "우리 동네 맛집", description: "메모", color: .orange,
    ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
    pinCount: 3, memberCount: 2, users: []
)

private let fixturePin = Pin(
    id: PinID("p1"), roomID: fixtureRoom.id, category: .worthVisiting,
    title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
    createdAt: Date(timeIntervalSince1970: 0)
)

@MainActor
struct ArchiveCoordinatorTests {
    private func makeCoordinator() -> ArchiveCoordinator {
        ArchiveCoordinator(deps: StubArchiveDeps())
    }

    @Test("생성 직후 내비게이션 스택은 비어 있다")
    func startsWithEmptyPath() {
        #expect(makeCoordinator().path.isEmpty)
    }

    @Test("생성 직후에는 방 리스트 단계다")
    func startsOnRoomList() {
        #expect(makeCoordinator().isRoomDetailPresented == false)
    }

    @Test("openRoomDetail 은 고른 방을 방 상세 단계로 올린다")
    func openRoomDetail() {
        let coordinator = makeCoordinator()
        coordinator.handle(.openRoomDetail(fixtureRoom))
        #expect(coordinator.selectedRoom == fixtureRoom)
        #expect(coordinator.isRoomDetailPresented)
    }

    @Test("close 는 방 리스트 단계로 되돌린다")
    func closeRoomDetail() {
        let coordinator = makeCoordinator()
        coordinator.handle(.openRoomDetail(fixtureRoom))
        coordinator.handle(RoomDetailNav.close)
        #expect(coordinator.selectedRoom == nil)
    }

    @Test("openPlaceDetail 은 고른 핀을 장소 상세 단계로 올린다")
    func openPlaceDetail() {
        let coordinator = makeCoordinator()
        coordinator.handle(.openRoomDetail(fixtureRoom))
        coordinator.handle(RoomDetailNav.openPlaceDetail(fixturePin))
        #expect(coordinator.selectedPin == fixturePin)
    }

    @Test("장소 상세를 닫으면 방 상세 단계로 되돌린다")
    func closePlaceDetail() {
        let coordinator = makeCoordinator()
        coordinator.handle(.openRoomDetail(fixtureRoom))
        coordinator.handle(RoomDetailNav.openPlaceDetail(fixturePin))
        coordinator.handle(PlaceDetailNav.close)
        #expect(coordinator.selectedPin == nil)
        #expect(coordinator.selectedRoom == fixtureRoom)
    }

    @Test("방 상세를 닫으면 열려 있던 장소 상세도 함께 정리한다")
    func closeRoomDetail_clearsPlace() {
        let coordinator = makeCoordinator()
        coordinator.handle(.openRoomDetail(fixtureRoom))
        coordinator.handle(RoomDetailNav.openPlaceDetail(fixturePin))
        coordinator.handle(RoomDetailNav.close)
        #expect(coordinator.selectedPin == nil)
    }

    @Test("장소 상세의 공유도 같은 공유 시트로 넘어간다")
    func sharePlaceDetail() {
        let coordinator = makeCoordinator()
        let location = RoomDetailLocation(from: fixturePin)
        coordinator.handle(PlaceDetailNav.share(location))
        #expect(coordinator.sharingLocation == location)
    }

    @Test("shareLocation 은 공유할 장소를 껍데기에 넘긴다")
    func shareLocation() {
        let coordinator = makeCoordinator()
        let location = RoomDetailLocation(
            id: "p1", name: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
            commentCount: 0, photoCount: 1
        )
        coordinator.handle(RoomDetailNav.shareLocation(location))
        #expect(coordinator.sharingLocation == location)
    }

    @Test("goToCreateRoom 은 방 만들기 화면을 push 하고 탭바를 감춘다")
    func handleGoToCreateRoom_pushes() {
        let coordinator = ArchiveCoordinator(deps: StubArchiveDeps())

        coordinator.handle(RoomListNav.goToCreateRoom)

        #expect(coordinator.path == [.createRoom])
        #expect(coordinator.isFullBleedContentPresented)
    }

    @Test("방 만들기의 확정·취소·건너뛰기는 모두 방 리스트로 pop 한다")
    func handleRoomFormNav_popsToRoomList() {
        for nav: RoomFormNav in [.didSubmit, .didCancel, .didSkip] {
            let coordinator = ArchiveCoordinator(deps: StubArchiveDeps())
            coordinator.handle(RoomListNav.goToCreateRoom)

            coordinator.handle(nav)

            #expect(coordinator.path.isEmpty)
            #expect(!coordinator.isFullBleedContentPresented)
        }
    }

    @Test("배선 — RoomForm Store 의 저장 확인이 path 에 반영된다")
    func roomFormStore_isWiredToPath() async {
        let coordinator = ArchiveCoordinator(deps: StubArchiveDeps())
        coordinator.handle(RoomListNav.goToCreateRoom)

        let store = coordinator.makeRoomFormStore()
        store.send(.roomNameChanged("민호야 잘하자"))   // reduce 가 확정 조건을 가드하므로 이름을 먼저 넣는다
        store.send(.tapSubmit)                        // 확인 다이얼로그를 띄우기만 한다
        store.send(.confirmSubmit)

        await waitUntil { coordinator.path.isEmpty }
        #expect(coordinator.path.isEmpty)
    }
}

/// 조건이 참이 될 때까지 짧게 폴링한다(상한 있음 — 무한 hang 금지).
@MainActor
private func waitUntil(_ condition: () -> Bool, limit: Int = 100) async {
    for _ in 0..<limit {
        if condition() { return }
        await Task.yield()
    }
}
