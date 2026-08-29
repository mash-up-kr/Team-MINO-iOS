import Foundation
import Testing
import Domain
import MVITestSupport
@testable import PlaceDetailUI

private let savedPin = PinFixture.pin(
    id: PinID("p1"),
    roomID: "room-A",
    category: .worthVisiting,
    title: "레이어스튜디오 10",
    address: "서울 성동구 상원4길 10",
    createdAt: Date(timeIntervalSince1970: 0)
)

private let roomB = SavedRoomFixture.room("room-B", name: "우리 동네 맛집", pinCount: 3)
private let roomC = SavedRoomFixture.room("room-C", name: "가고싶은 카페", pinCount: 5)

/// 출처 조회를 조용히 끝내는 스텁 — 이 파일은 저장된 방만 본다.
private struct QuietFetchPinDetail: FetchPinDetailUseCase {
    func execute(pinID: PinID) async throws -> PinDetail { PinDetail(pin: savedPin, sourceURL: nil) }
}

private struct QuietCurrentMember: CurrentMemberUseCase {
    func execute() async throws -> MemberProfile {
        MemberProfile(id: MemberID("user-0001"), nickname: "나", avatarColor: .red)
    }
}

/// 현위치 조회는 이 스위트의 관심사가 아니다 — 부르지 않는다.
private struct QuietCurrentLocation: CurrentLocationUseCase {
    func execute() async -> CurrentLocationResult { .unavailable }
}

/// 저장된 방 목록(기획 014 ②)과 그 진입 버튼(기획 005-1 ⑮)의 규칙.
@MainActor
struct PlaceDetailSavedRoomsTests {
    private func makeStore(
        savedRooms: StubFetchSavedRooms.Outcome = .rooms([]),
        state: PlaceDetailState? = nil
    ) -> TestStore<PlaceDetailState, PlaceDetailAction, PlaceDetailNav> {
        TestStore(
            state ?? PlaceDetailState(place: PlaceDetailPlace(from: savedPin, label: nil)),
            reduce: placeDetailReducer(
                useCase: QuietFetchPinDetail(),
                fetchCurrentMember: QuietCurrentMember(),
                fetchSavedRooms: StubFetchSavedRooms(outcome: savedRooms),
                fetchComments: StubFetchPinComments(),
                postComment: StubPostPinComment(outcome: .failure(.unknown)),
                deleteComment: StubDeletePinComment(),
                currentLocation: QuietCurrentLocation(),
                pin: savedPin
            )
        )
    }

    private func loadedState(rooms: [Room]) -> PlaceDetailState {
        var state = PlaceDetailState(place: PlaceDetailPlace(from: savedPin, label: nil))
        state.savedRooms = rooms
        return state
    }

    // MARK: - 조회

    @Test("L2 — loadSavedRooms 는 중복 저장된 방을 받아 버튼을 연다")
    func load_success() async {
        let store = makeStore(savedRooms: .rooms([roomB, roomC]))

        await store.send(.loadSavedRooms) { $0.isLoadingSavedRooms = true }
        await store.receive(.savedRoomsLoaded([roomB, roomC])) {
            $0.savedRooms = [roomB, roomC]
            $0.isLoadingSavedRooms = false
        }

        #expect(store.currentState.canOpenSavedRooms)
        store.finish()
    }

    @Test("L2 — 중복 저장이 아니면 목록이 비고 버튼이 닫힌 채 남는다")
    func load_empty() async {
        let store = makeStore(savedRooms: .rooms([]))

        await store.send(.loadSavedRooms) { $0.isLoadingSavedRooms = true }
        await store.receive(.savedRoomsLoaded([])) { $0.isLoadingSavedRooms = false }

        #expect(store.currentState.canOpenSavedRooms == false)
        store.finish()
    }

    @Test("L2 — 조회 실패는 오류 UI 없이 버튼만 닫아 둔다")
    func load_failure() async {
        let store = makeStore(savedRooms: .failure(.unknown), state: loadedState(rooms: [roomB]))

        await store.send(.loadSavedRooms) { $0.isLoadingSavedRooms = true }
        await store.receive(.savedRoomsLoadFailed(.unknown)) {
            // 못 받은 목록으로 시트를 여는 것보다 안 열리는 게 낫다 — 남아 있던 목록도 비운다.
            $0.savedRooms = []
            $0.isLoadingSavedRooms = false
        }

        #expect(store.currentState.canOpenSavedRooms == false)
        store.finish()
    }

    @Test("L2 — 취소는 실패가 아니다: 결과 action 이 오지 않는다")
    func load_cancelled() async {
        let store = makeStore(savedRooms: .cancelled)

        await store.send(.loadSavedRooms) { $0.isLoadingSavedRooms = true }

        // 취소는 "결과를 못 얻은 것"이 아니라 "결과가 필요 없어진 것" — state 를 건드리지 않는다.
        store.finish()
    }

    @Test("L1 — 이미 조회 중이면 중복 요청하지 않는다")
    func load_ignoresWhileLoading() async {
        var state = PlaceDetailState(place: PlaceDetailPlace(from: savedPin, label: nil))
        state.isLoadingSavedRooms = true
        let store = makeStore(savedRooms: .rooms([roomB]), state: state)

        await store.send(.loadSavedRooms)   // 상태 변화 없음, effect 도 없음

        store.finish()
    }

    // MARK: - 진입 (005-1 ⑮ → 014)

    @Test("L1 — 버튼을 누르면 받아 둔 목록을 그대로 시트에 실어 보낸다")
    func tap_navigatesWithLoadedRooms() async {
        let store = makeStore(state: loadedState(rooms: [roomB, roomC]))

        await store.send(.tapSavedRooms)

        store.receiveNavigation(
            .openSavedRooms(SavedRoomsPresentation(id: "p1", rooms: [roomB, roomC]))
        )
        store.finish()
    }

    @Test("L1 — 목록이 비면 눌러도 열리지 않는다 (중복 저장된 장소에서만 활성)")
    func tap_ignoredWhenEmpty() async {
        let store = makeStore(state: loadedState(rooms: []))

        await store.send(.tapSavedRooms)   // 상태 변화도 navigation 도 없음

        store.finish()
    }
}
