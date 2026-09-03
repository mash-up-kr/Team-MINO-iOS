import Foundation
import Testing
import Domain
import MVITestSupport
@testable import PlaceDetailUI

private let fixtureNow = Date(timeIntervalSince1970: 1_700_000_000)

private let fixturePin = PinFixture.pin(
    id: PinID("p1"),
    roomID: "r1",
    category: .worthVisiting,
    title: "레이어스튜디오 10",
    address: "서울 성동구 상원4길 10",
    createdAt: fixtureNow.addingTimeInterval(-29 * 86_400)
)

private let fixtureSourceURL = URL(string: "https://www.instagram.com/p/mock-layer10/")!

/// 현재 사용자 조회를 즉답시키는 스텁.
private struct StubCurrentMember: CurrentMemberUseCase {
    let profile: MemberProfile
    func execute() async throws -> MemberProfile { profile }
}

/// 핀 단독 조회를 즉답시키는 스텁 — 출처가 있는 핀·없는 핀·조회 실패·취소를 골라 재생한다.
private struct StubFetchPinDetail: FetchPinDetailUseCase {
    enum Outcome: Sendable {
        case source(URL?)
        case failure(DomainError)
        case cancelled
    }

    let outcome: Outcome

    func execute(pinID: PinID) async throws -> PinDetail {
        switch outcome {
        case .source(let url): return PinDetail(pin: fixturePin, sourceURL: url)
        case .failure(let error): throw error
        case .cancelled: throw CancellationError()
        }
    }
}

/// 현위치 조회를 즉답시키는 스텁 — 좌표·권한 거부·측위 실패를 골라 재생한다.
private struct StubCurrentLocation: CurrentLocationUseCase {
    var result: CurrentLocationResult = .coordinate(fixtureMyCoordinate)

    func execute() async -> CurrentLocationResult { result }
}

private let fixtureMyCoordinate = Coordinate(latitude: 37.5443, longitude: 127.0557)

private let fixtureAuthor = MemberProfile(id: MemberID("user-0001"), nickname: "나", avatarColor: .red)

@MainActor
struct PlaceDetailReducerTests {
    private func makeStore(
        source: StubFetchPinDetail.Outcome = .source(fixtureSourceURL),
        location: CurrentLocationResult = .coordinate(fixtureMyCoordinate),
        recordPinAccess: RecordPinAccessUseCase = SpyRecordPinAccess()
    ) -> TestStore<PlaceDetailState, PlaceDetailAction, PlaceDetailNav> {
        TestStore(
            PlaceDetailState(place: PlaceDetailPlace(from: fixturePin, label: nil), currentMember: fixtureAuthor),
            reduce: placeDetailReducer(
                useCase: StubFetchPinDetail(outcome: source),
                fetchCurrentMember: StubCurrentMember(profile: fixtureAuthor),
                fetchSavedRooms: StubFetchSavedRooms(),
                fetchComments: StubFetchPinComments(),
                postComment: StubPostPinComment(outcome: .failure(.unknown)),
                deleteComment: StubDeletePinComment(),
                currentLocation: StubCurrentLocation(result: location),
                recordPinAccess: recordPinAccess,
                pin: fixturePin
            )
        )
    }

    @Test("L2 — load 는 출처 링크를 받아 원문보기를 열 수 있게 만든다")
    func loadSource() async {
        let store = makeStore(source: .source(fixtureSourceURL))
        await store.send(.load) { $0.isLoadingSource = true }
        await store.receive(.sourceLoaded(fixtureSourceURL)) {
            $0.sourceURL = fixtureSourceURL
            $0.isLoadingSource = false
        }
        store.finish()
    }

    @Test("L2 — 출처가 없는 핀은 sourceURL 이 nil 로 남는다")
    func loadSource_absent() async {
        let store = makeStore(source: .source(nil))
        await store.send(.load) { $0.isLoadingSource = true }
        await store.receive(.sourceLoaded(nil)) { $0.isLoadingSource = false }
        #expect(store.currentState.sourceURL == nil)
        store.finish()
    }

    @Test("L2 — 조회에 실패해도 오류를 화면에 흘리지 않고 비활성으로 남긴다")
    func loadSource_failure() async {
        let store = makeStore(source: .failure(.unknown))
        await store.send(.load) { $0.isLoadingSource = true }
        await store.receive(.sourceLoadFailed(.unknown)) { $0.isLoadingSource = false }
        #expect(store.currentState.sourceURL == nil)
        store.finish()
    }

    @Test("L2 — 취소는 실패가 아니라 결과가 필요 없어진 것이라 아무 action 도 돌아오지 않는다")
    func loadSource_cancelled() async {
        let store = makeStore(source: .cancelled)
        await store.send(.load) { $0.isLoadingSource = true }
        store.finish()
    }

    @Test("L1 — 조회가 진행 중이면 load 를 다시 받아도 중복 조회하지 않는다")
    func load_isIdempotentWhileLoading() async {
        let store = makeStore(source: .cancelled)
        await store.send(.load) { $0.isLoadingSource = true }
        await store.send(.load)
        store.finish()
    }

    // MARK: - 「경과일 초기화 확인」 (spec FR-007 · Figma 002-1 주석 ③)

    @Test("L2 — 상세가 열리면 이 핀으로 기록을 정확히 1회 보낸다")
    func load_recordsAccessOnce() async {
        let spy = SpyRecordPinAccess()
        let store = makeStore(recordPinAccess: spy)

        await store.send(.load) { $0.isLoadingSource = true }
        await store.receive(.sourceLoaded(fixtureSourceURL)) {
            $0.sourceURL = fixtureSourceURL
            $0.isLoadingSource = false
        }

        #expect(await spy.recorded == [fixturePin.id])
        store.finish()
    }

    @Test("L1 — 조회 중 들어온 두 번째 load 는 기록도 다시 보내지 않는다")
    func load_doesNotRecordAccessTwiceWhileLoading() async {
        let spy = SpyRecordPinAccess()
        let store = makeStore(source: .cancelled, recordPinAccess: spy)

        await store.send(.load) { $0.isLoadingSource = true }
        await store.send(.load)

        #expect(await spy.recorded == [fixturePin.id])
        store.finish()
    }

    @Test("L2 — 기록이 실패해도 화면은 그대로다 — 재시도도 안내도 없다 (EC-022)")
    func recordAccessFailure_leavesScreenUntouched() async {
        let spy = SpyRecordPinAccess(failure: .unknown)
        let store = makeStore(recordPinAccess: spy)

        await store.send(.load) { $0.isLoadingSource = true }
        // 성공했을 때와 같은 전이다 — exhaustive 단언이라 실패가 state 를 건드렸으면 여기서 걸린다.
        await store.receive(.sourceLoaded(fixtureSourceURL)) {
            $0.sourceURL = fixtureSourceURL
            $0.isLoadingSource = false
        }

        #expect(await spy.recorded == [fixturePin.id])
        store.finish()   // 실패를 알리는 Response Action 도 없었음을 잔여 검사로 확인한다
    }

    @Test("L1 — tapClose 는 close 로 navigate 한다")
    func tapClose() async {
        let store = makeStore()
        await store.send(.tapClose)
        store.receiveNavigation(.close)
        store.finish()
    }

    @Test("L1 — tapShare 는 이 장소를 도메인 핀 그대로 실어 navigate 한다")
    func tapShare() async {
        let store = makeStore()
        await store.send(.tapShare)
        store.receiveNavigation(.share(fixturePin))
        store.finish()
    }

    // MARK: - 현위치 (005-1 지도 우하단 버튼)

    @Test("L2 — 현위치를 누르면 좌표를 받아 지도를 그 자리로 옮긴다")
    func tapMyLocation_focusesMap() async {
        let store = makeStore(location: .coordinate(fixtureMyCoordinate))

        await store.send(.tapMyLocation) { $0.isLocating = true }
        await store.receive(.myLocationResolved(.coordinate(fixtureMyCoordinate))) {
            $0.isLocating = false
        }

        store.receiveNavigation(.focusMyLocation(fixtureMyCoordinate))
        store.finish()
    }

    @Test("L2 — 권한이 거부되면 아무 데도 가지 않는다 — 시안 005-1 에 실패 안내가 없다")
    func tapMyLocation_permissionDenied_doesNothing() async {
        let store = makeStore(location: .permissionDenied)

        await store.send(.tapMyLocation) { $0.isLocating = true }
        await store.receive(.myLocationResolved(.permissionDenied)) { $0.isLocating = false }

        store.finish()   // navigate 가 없었음을 잔여 검사로 확인한다
    }

    @Test("L2 — 측위에 실패해도 아무 데도 가지 않는다")
    func tapMyLocation_unavailable_doesNothing() async {
        let store = makeStore(location: .unavailable)

        await store.send(.tapMyLocation) { $0.isLocating = true }
        await store.receive(.myLocationResolved(.unavailable)) { $0.isLocating = false }

        store.finish()
    }

    @Test("L1 — 기다리는 중 다시 눌러도 요청을 겹쳐 내보내지 않는다")
    func tapMyLocation_ignoresWhileLocating() async {
        let store = makeStore()

        await store.send(.tapMyLocation) { $0.isLocating = true }
        await store.send(.tapMyLocation)   // 두 번째 탭은 effect 를 만들지 않는다

        await store.receive(.myLocationResolved(.coordinate(fixtureMyCoordinate))) {
            $0.isLocating = false
        }
        store.receiveNavigation(.focusMyLocation(fixtureMyCoordinate))
        store.finish()
    }

    @Test("L1 — 결과가 돌아온 뒤에는 다시 누를 수 있다")
    func tapMyLocation_canRetryAfterResult() async {
        let store = makeStore()

        await store.send(.tapMyLocation) { $0.isLocating = true }
        await store.receive(.myLocationResolved(.coordinate(fixtureMyCoordinate))) {
            $0.isLocating = false
        }
        store.receiveNavigation(.focusMyLocation(fixtureMyCoordinate))

        await store.send(.tapMyLocation) { $0.isLocating = true }
        await store.receive(.myLocationResolved(.coordinate(fixtureMyCoordinate))) {
            $0.isLocating = false
        }
        store.receiveNavigation(.focusMyLocation(fixtureMyCoordinate))
        store.finish()
    }
}

struct PlaceDetailExternalMapTests {
    @Test("주소를 검색어로 실은 지도 URL 을 만든다")
    func buildsSearchURL() {
        let url = PlaceDetailExternalMap.url(forAddress: "서울 성동구 상원4길 10")
        #expect(url?.absoluteString == "https://maps.apple.com/?q=%EC%84%9C%EC%9A%B8%20%EC%84%B1%EB%8F%99%EA%B5%AC%20%EC%83%81%EC%9B%904%EA%B8%B8%2010")
    }

    @Test("주소가 비어 있으면 URL 을 만들지 않는다")
    func rejectsBlankAddress() {
        #expect(PlaceDetailExternalMap.url(forAddress: "   ") == nil)
    }
}
