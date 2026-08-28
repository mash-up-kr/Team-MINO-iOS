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


private struct StubFetchPinDetail: FetchPinDetailUseCase {
    func execute(pinID: PinID) async throws -> PinDetail {
        PinDetail(pin: fixturePin, sourceURL: nil)
    }
}

private struct StubCreateRoom: CreateRoomUseCase {
    func execute(name: String, description: String?, color: RoomColor) async throws -> Room {
        Room(
            id: "new", type: .shared, name: name, description: description, color: color,
            ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
            pinCount: 0, memberCount: 1, users: []
        )
    }
}

private struct StubShareTargets: FetchShareTargetsUseCase {
    func execute(pinID: PinID) async throws -> [ShareTarget] { [] }
}

private struct StubSavePin: SavePinToRoomsUseCase {
    func execute(pinID: PinID, roomIDs: Set<String>) async throws {}
}

private struct StubDeletePin: DeletePinUseCase {
    func execute(pinID: PinID) async throws {}
}

private struct StubCurrentMember: CurrentMemberUseCase {
    func execute() async throws -> MemberProfile {
        MemberProfile(id: MemberID("user-0001"), nickname: "나", avatarID: 1)
    }
}

private struct StubArchiveDeps: ArchiveDeps {
    var fetchRooms: FetchRoomsUseCase = StubFetchRooms()
    var fetchPins: FetchPinsUseCase = StubFetchPins()
    var fetchPinDetail: FetchPinDetailUseCase = StubFetchPinDetail()
    var createRoom: CreateRoomUseCase = StubCreateRoom()
    var fetchShareTargets: FetchShareTargetsUseCase = StubShareTargets()
    var fetchSavedRooms: FetchSavedRoomsUseCase = StubFetchSavedRooms()
    var savePin: SavePinToRoomsUseCase = StubSavePin()
    var deletePin: DeletePinUseCase = StubDeletePin()
    var currentMember: CurrentMemberUseCase = StubCurrentMember()
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

private let savedRoomB = SavedRoomFixture.room("room-B", name: "가고싶은 카페", pinCount: 5)

private let fixturePin = PinFixture.pin(
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
            commentCount: 0, photos: []
        )
        coordinator.handle(RoomDetailNav.shareLocation(location))
        #expect(coordinator.sharingLocation == location)
    }

    @Test("공유 저장이 끝나면 시트를 닫고 완료 신호를 1회만 남긴다")
    func shareDidSave_closesSheetAndSignalsOnce() {
        let coordinator = makeCoordinator()
        coordinator.handle(RoomDetailNav.shareLocation(RoomDetailLocation(from: fixturePin)))

        coordinator.handle(RoomShareNav.didSave)

        #expect(coordinator.sharingLocation == nil)
        #expect(coordinator.consumeSavedShare())
        #expect(coordinator.consumeSavedShare() == false)   // 같은 저장으로 토스트가 두 번 뜨지 않는다
    }

    @Test("X 로 닫으면 완료 신호가 서지 않는다")
    func shareClose_leavesNoSignal() {
        let coordinator = makeCoordinator()
        coordinator.handle(RoomDetailNav.shareLocation(RoomDetailLocation(from: fixturePin)))

        coordinator.sharingLocation = nil   // 껍데기의 onClose 와 같은 경로

        #expect(coordinator.consumeSavedShare() == false)
    }

    @Test("배선 — 공유 Store 의 저장 완료가 시트를 닫는다")
    func roomShareStore_isWiredToSheet() async {
        let coordinator = makeCoordinator()
        let location = RoomDetailLocation(from: fixturePin)
        coordinator.handle(RoomDetailNav.shareLocation(location))

        let store = coordinator.makeRoomShareStore(location: location)
        store.send(.loaded([ShareTarget(room: fixtureRoom, alreadySaved: false)]))
        store.send(.toggleRoom(fixtureRoom.id))   // reduce 가 빈 선택을 가드하므로 먼저 고른다
        store.send(.tapSubmit)

        await waitUntil { coordinator.sharingLocation == nil }
        #expect(coordinator.sharingLocation == nil)
        #expect(coordinator.consumeSavedShare())
    }

    // MARK: - 공유 시트에서 새 방 만들기 (기획 011-1 ③)

    @Test("공유 시트의 새 방 만들기는 시트를 닫지 않고 그 위에 만들기 flow 를 올린다")
    func shareGoToCreateRoom_coversSheetWithoutClosingIt() {
        let coordinator = makeCoordinator()
        let location = RoomDetailLocation(from: fixturePin)
        coordinator.handle(RoomDetailNav.shareLocation(location))

        coordinator.handle(RoomShareNav.goToCreateRoom)

        #expect(coordinator.shareCreateRoomChild != nil)
        // 시트가 살아 있어야 돌아왔을 때 고르던 선택이 남는다.
        #expect(coordinator.sharingLocation == location)
        // 탭 스택은 건드리지 않는다 — 시트 위 커버라 push 가 아니다.
        #expect(coordinator.path.isEmpty)
    }

    @Test("배선 — 자식 만들기 flow 의 저장 확인이 created 로 보고된다")
    func shareCreateRoomStore_isWiredToFinish() async throws {
        let coordinator = makeCoordinator()
        coordinator.handle(RoomDetailNav.shareLocation(RoomDetailLocation(from: fixturePin)))
        coordinator.handle(RoomShareNav.goToCreateRoom)
        let child = try #require(coordinator.shareCreateRoomChild)

        var reported: RoomShareCreateRoomResult?
        child.finish.bind { reported = $0 }   // flowRoot 가 하는 bind 를 테스트가 대신한다

        let store = child.makeRoomFormStore()
        store.send(.roomNameChanged("민호야 잘하자"))   // reduce 가 확정 조건을 가드한다
        store.send(.tapSubmit)                        // 확인 다이얼로그를 띄우기만 한다
        store.send(.confirmSubmit)

        await waitUntil { reported != nil }
        #expect(reported == .created)
    }

    @Test("자식 만들기 flow 를 그만두면 cancelled 로 보고된다")
    func shareCreateRoom_cancel_reportsCancelled() throws {
        let coordinator = makeCoordinator()
        coordinator.handle(RoomDetailNav.shareLocation(RoomDetailLocation(from: fixturePin)))
        coordinator.handle(RoomShareNav.goToCreateRoom)
        let child = try #require(coordinator.shareCreateRoomChild)

        var reported: RoomShareCreateRoomResult?
        child.finish.bind { reported = $0 }

        child.handle(RoomFormNav.didCancel)

        #expect(reported == .cancelled)
    }

    @Test("자식 만들기 flow 는 결과를 1회만 보고한다")
    func shareCreateRoom_reportsOnce() throws {
        let coordinator = makeCoordinator()
        coordinator.handle(RoomDetailNav.shareLocation(RoomDetailLocation(from: fixturePin)))
        coordinator.handle(RoomShareNav.goToCreateRoom)
        let child = try #require(coordinator.shareCreateRoomChild)

        var reported: [RoomShareCreateRoomResult] = []
        child.finish.bind { reported.append($0) }

        child.handle(RoomFormNav.didSubmit(roomId: "room-9"))
        child.handle(RoomFormNav.didCancel)   // 커버가 닫히는 사이 들어온 두 번째 신호

        #expect(reported == [.created])
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
        for nav: RoomFormNav in [.didSubmit(roomId: "room-1"), .didCancel, .didSkip] {
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

    // MARK: - 저장된 방 (005-1 ⑮ → 014)

    @Test("openSavedRooms 는 받은 목록을 그대로 시트 항목으로 올린다")
    func openSavedRooms() {
        let coordinator = makeCoordinator()
        let presentation = SavedRoomsPresentation(id: "p1", rooms: [savedRoomB])

        coordinator.handle(PlaceDetailNav.openSavedRooms(presentation))

        #expect(coordinator.savedRooms == presentation)
    }

    @Test("방 카드를 고르면 시트를 닫고 그 방으로 갈아끼운다 — 보던 장소는 그대로다")
    func selectSavedRoom_switchesRoomKeepingPlace() {
        let coordinator = makeCoordinator()
        coordinator.handle(.openRoomDetail(fixtureRoom))
        coordinator.handle(RoomDetailNav.openPlaceDetail(fixturePin))
        coordinator.handle(
            PlaceDetailNav.openSavedRooms(SavedRoomsPresentation(id: "p1", rooms: [savedRoomB]))
        )

        coordinator.selectSavedRoom(savedRoomB.id)

        #expect(coordinator.savedRooms == nil)
        #expect(coordinator.selectedRoom == savedRoomB)
        #expect(coordinator.selectedPin == fixturePin)   // 장소 상세는 닫히지 않는다
    }

    @Test("목록에 없는 방 id 는 무시한다 — 시트도 방도 그대로")
    func selectSavedRoom_ignoresUnknownID() {
        let coordinator = makeCoordinator()
        coordinator.handle(.openRoomDetail(fixtureRoom))
        let presentation = SavedRoomsPresentation(id: "p1", rooms: [savedRoomB])
        coordinator.handle(PlaceDetailNav.openSavedRooms(presentation))

        coordinator.selectSavedRoom("room-없음")

        #expect(coordinator.savedRooms == presentation)
        #expect(coordinator.selectedRoom == fixtureRoom)
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
