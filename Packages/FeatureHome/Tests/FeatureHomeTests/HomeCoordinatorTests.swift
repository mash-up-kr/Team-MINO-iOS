import Domain
import Foundation
import PlaceDetailUI
import RoomCreationUI
import RoomShareUI
import Testing
@testable import FeatureHome

private struct StubDeps: HomeDeps {
    var fetchRooms: FetchRoomsUseCase = StubFetchRooms()
    var fetchHomeCards: FetchHomeCardsUseCase = StubFetchHomeCards()
    var lastViewedRoom: LastViewedRoomUseCase = StubLastViewedRoom()
    var homeGuide: HomeGuideUseCase = StubHomeGuide()
    var savePin: SavePinToRoomsUseCase = StubSavePin()
    var createRoom: CreateRoomUseCase = StubCreateRoom()
    var fetchProfile: FetchProfileUseCase = StubFetchProfile()
    var recordPinAccess: RecordPinAccessUseCase = StubRecordPinAccess()
    var fetchShareTargets: FetchShareTargetsUseCase = StubUnused()
    // 장소 상세(PlaceDetailDeps) 몫 — 라우팅 테스트는 Store 를 만들지 않아 호출되지 않는다.
    var fetchPinDetail: FetchPinDetailUseCase = StubUnused()
    var currentMember: CurrentMemberUseCase = StubUnused()
    var fetchSavedRooms: FetchSavedRoomsUseCase = StubUnused()
    var fetchComments: FetchPinCommentsUseCase = StubUnused()
    var postComment: PostPinCommentUseCase = StubUnused()
    var deleteComment: DeletePinCommentUseCase = StubUnused()
    var currentLocation: CurrentLocationUseCase = StubUnused()
}

/// 이 스위트가 쓰지 않는 장소 상세 유스케이스들. 불리면 값이 아니라 **실패**를 돌려준다 —
/// 조용한 기본값을 주면 나중에 실제로 부르는 경로가 생겨도 테스트가 통과해 버린다.
private struct StubUnused: FetchPinDetailUseCase, CurrentMemberUseCase, FetchSavedRoomsUseCase,
                           FetchPinCommentsUseCase, PostPinCommentUseCase, DeletePinCommentUseCase,
                           CurrentLocationUseCase, FetchShareTargetsUseCase {
    func execute(pinID: PinID) async throws -> [ShareTarget] { throw DomainError.unknown }
    func execute(pinID: PinID) async throws -> PinDetail { throw DomainError.unknown }
    func execute() async throws -> MemberProfile { throw DomainError.unknown }
    func execute(pin: Pin) async throws -> [Room] { throw DomainError.unknown }
    func execute(pinID: PinID) async throws -> [PinComment] { throw DomainError.unknown }
    func execute(pinID: PinID, body: String) async throws -> PinComment { throw DomainError.unknown }
    func execute(commentID: PinCommentID) async throws { throw DomainError.unknown }
    // 현위치만 throw 할 수 없다(유스케이스가 throws 가 아니다) — 못 얻은 것으로 답한다.
    func execute() async -> CurrentLocationResult { .unavailable }
}

/// 마스코트 색 조회. 이 스위트는 라우팅만 보므로 값이 필요 없다 — 실패해도 마스코트가
/// 기본 그림으로 떨어질 뿐이라 라우팅 단언에 영향이 없다.
private struct StubFetchProfile: FetchProfileUseCase {
    func execute() async throws -> Profile { throw DomainError.unknown }
}

/// 「경과일 초기화 확인」. 라우팅만 보는 스위트라 아무것도 하지 않는다.
private struct StubRecordPinAccess: RecordPinAccessUseCase {
    func execute(pinID: PinID) async throws {}
}

private struct StubFetchRooms: FetchRoomsUseCase {
    func execute() async throws -> [Room] { [] }
}

private struct StubFetchHomeCards: FetchHomeCardsUseCase {
    func execute(room: Room, filter: PinFilter, origin: Coordinate?) async throws -> [Pin] { [] }
}

private struct StubLastViewedRoom: LastViewedRoomUseCase {
    func load() async -> String? { nil }
    func save(roomID: String) async {}
}

private struct StubHomeGuide: HomeGuideUseCase {
    func hasSeen() async -> Bool { true }
    func markSeen() async {}
}

private struct StubSavePin: SavePinToRoomsUseCase {
    func execute(pinID: PinID, roomIDs: Set<String>) async throws {}
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


@MainActor
struct HomeCoordinatorTests {
    @Test("생성 직후 내비게이션 스택은 비어 있다")
    func startsWithEmptyPath() {
        #expect(HomeCoordinator(deps: StubDeps()).path.isEmpty)
    }

    @Test("goToCreateRoom 은 방 만들기 화면을 push 한다")
    func handleGoToCreateRoom_pushes() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        coordinator.handle(HomeNav.goToCreateRoom)
        #expect(coordinator.path == [.createRoom])
    }

    @Test("방 만들기에서 didSubmit 은 홈으로 pop 한다")
    func handleRoomFormNav_popsHome() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        coordinator.handle(HomeNav.goToCreateRoom)
        coordinator.handle(RoomFormNav.didSubmit(roomId: "room-1"))
        #expect(coordinator.path.isEmpty)
    }

    // MARK: - 장소 상세 (지도 + 시트)

    private func pin(_ id: String, lat: Double = 37.5, lng: Double = 127.0) -> Pin {
        PinFixture.pin(
            id: PinID(id),
            roomID: "r1",
            category: .worthVisiting,
            title: "장소 \(id)",
            address: "주소 \(id)",
            coordinate: Coordinate(latitude: lat, longitude: lng),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    @Test("카드에서 장소를 열면 그 핀이 선다")
    func openPlaceDetail_setsPin() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        let target = pin("a")
        coordinator.handle(.openPlaceDetail(target))
        #expect(coordinator.selectedPin == target)
    }

    @Test("장소 상세가 열리면 탭바를 레이아웃에서 뺀다 — 남으면 시트 하단이 가린다")
    func placeDetailHidesTabBar() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        #expect(!coordinator.isFullBleedContentPresented)

        coordinator.handle(.openPlaceDetail(pin("a")))
        #expect(coordinator.isFullBleedContentPresented)
    }

    @Test("장소 상세를 닫으면 탭바가 돌아온다")
    func closingPlaceDetailRestoresTabBar() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        coordinator.handle(.openPlaceDetail(pin("a")))
        coordinator.handle(PlaceDetailNav.close)

        #expect(coordinator.selectedPin == nil)
        #expect(!coordinator.isFullBleedContentPresented)
    }

    // MARK: - 다른 방에 공유 (011-1)

    @Test("L2 — '다른 방에 공유'는 장소 상세를 닫지 않고 그 위에 공유 시트를 얹는다")
    func share_keepsPlaceDetailOpen() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        let target = pin("a")
        coordinator.handle(.openPlaceDetail(target))

        coordinator.handle(PlaceDetailNav.share(target))

        #expect(coordinator.sharingPin == target)
        // 상세가 살아 있어야 시트가 지도·상세 위에 얹힌다 — 닫으면 어디서 눌렀는지 사라진다.
        #expect(coordinator.selectedPin == target)
        #expect(coordinator.placeDetailStore != nil)
    }

    @Test("L1 — 공유 저장이 끝나면 시트만 닫는다 (상세는 그대로)")
    func shareDidSave_closesOnlyTheSheet() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        let target = pin("a")
        coordinator.handle(.openPlaceDetail(target))
        coordinator.handle(PlaceDetailNav.share(target))

        coordinator.handle(RoomShareNav.didSave)

        #expect(coordinator.sharingPin == nil)
        #expect(coordinator.selectedPin == target)
    }

    @Test("L1 — 공유 시트에서 방 만들기로 가면 시트를 닫지 않고 그 위를 덮는다 (011-1 ③)")
    func shareGoToCreateRoom_keepsSheet() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        let target = pin("a")
        coordinator.handle(.openPlaceDetail(target))
        coordinator.handle(PlaceDetailNav.share(target))

        coordinator.handle(RoomShareNav.goToCreateRoom)

        #expect(coordinator.shareCreateRoomChild != nil)
        // 닫으면 고르던 방 선택이 사라진다 — 시트는 그대로 남아야 한다.
        #expect(coordinator.sharingPin == target)
    }

    @Test("현위치 요청은 그 좌표를 세운다")
    func focusMyLocation_setsCoordinate() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        coordinator.handle(.openPlaceDetail(pin("a")))

        let me = Coordinate(latitude: 37.5443, longitude: 127.0557)
        coordinator.handle(PlaceDetailNav.focusMyLocation(me))

        #expect(coordinator.mapFocus?.coordinate == me)
    }

    @Test("같은 자리를 다시 눌러도 새 요청이다 — 지도를 옮긴 뒤 눌러도 카메라가 돌아와야 한다")
    func repeatedFocusIsANewRequest() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        coordinator.handle(.openPlaceDetail(pin("a")))

        let me = Coordinate(latitude: 37.5443, longitude: 127.0557)
        coordinator.handle(PlaceDetailNav.focusMyLocation(me))
        let first = coordinator.mapFocus
        coordinator.handle(PlaceDetailNav.focusMyLocation(me))

        #expect(coordinator.mapFocus != first)
        #expect(coordinator.mapFocus?.coordinate == me)
    }

    @Test("다른 장소를 열면 이전 현위치 요청은 사라진다 — 남으면 새 장소가 화면 밖에 놓인다")
    func openingAnotherPlaceClearsFocus() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        coordinator.handle(.openPlaceDetail(pin("a")))
        coordinator.handle(PlaceDetailNav.focusMyLocation(Coordinate(latitude: 37.5443, longitude: 127.0557)))

        coordinator.handle(.openPlaceDetail(pin("b")))

        #expect(coordinator.mapFocus == nil)
    }

    @Test("상세를 닫아도 현위치 요청은 사라진다 — 지도가 그 장소와 수명을 같이한다")
    func closingClearsFocus() {
        let coordinator = HomeCoordinator(deps: StubDeps())
        coordinator.handle(.openPlaceDetail(pin("a")))
        coordinator.handle(PlaceDetailNav.focusMyLocation(Coordinate(latitude: 37.5443, longitude: 127.0557)))

        coordinator.handle(PlaceDetailNav.close)

        #expect(coordinator.mapFocus == nil)
    }
}
