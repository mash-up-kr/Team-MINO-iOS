import Foundation
import Testing
import Domain
import MVITestSupport
@testable import FeatureNotification

// [Convention] plan/background/retained/handoff-mvi-reduce-test.md 「이번 PR4 에서 실제로 쓰게 될 시나리오」

private let fixtureNow = Date(timeIntervalSince1970: 1_700_000_000)

/// 프로덕션의 `maxConsecutiveEmptyPages` 는 private 이라 여기서 값을 다시 적는다.
/// 어긋나면 상한 테스트가 실패하므로, 값을 바꿀 때 이 줄도 함께 고치라는 신호가 된다.
private let maxConsecutiveEmptyPagesForTest = 5

private func fixtureNotification(id: String, createdAt: Date = fixtureNow) -> AppNotification {
    AppNotification(
        id: NotificationID(id),
        type: .duplicateSave,
        title: "이미 저장해둔 곳이에요",
        targetName: "연남동 스탠딩 커피",
        thumbnailURL: nil,
        destination: .place(pinID: PinID("pin-\(id)")),
        createdAt: createdAt
    )
}

// destination 은 일부러 resolved 인 `.place` 로 둔다 — `.unresolved` 로 두면 `.unknown` 필터 줄을
// 지워도 셀이 안 그려질 이유가 따로 생겨, `.unknown` 필터를 실제로 검증하지 못하게 된다.
private func unknownTypeNotification(id: String) -> AppNotification {
    AppNotification(
        id: NotificationID(id), type: .unknown(raw: "future_type"),
        title: "무관", targetName: "무관", thumbnailURL: nil,
        destination: .place(pinID: PinID("pin-\(id)")), createdAt: fixtureNow
    )
}

/// 이동 대상 식별자가 없는 알림 — **걸러지지 않고 목록에 남는다**. 탭만 아무 일도 하지 않는다.
private func unresolvedNotification(id: String) -> AppNotification {
    AppNotification(
        id: NotificationID(id), type: .memberJoined,
        title: "새 멤버가 들어왔어요", targetName: "맛집 탐방", thumbnailURL: nil,
        destination: .unresolved, createdAt: fixtureNow
    )
}

private func roomNotification(id: String, roomID: String = "room-1") -> AppNotification {
    AppNotification(
        id: NotificationID(id), type: .roomJoined,
        title: "방에 참가했어요", targetName: "맛집 탐방", thumbnailURL: nil,
        destination: .room(roomID: roomID), createdAt: fixtureNow
    )
}

private func saveErrorNotification(id: String) -> AppNotification {
    AppNotification(
        id: NotificationID(id), type: .saveError,
        title: "장소를 저장하지 못했어요", targetName: "인스타그램 게시물", thumbnailURL: nil,
        destination: .saveError, createdAt: fixtureNow
    )
}

private let fixtureRoom = Room(
    id: "room-1", type: .shared, name: "맛집 탐방", description: nil, color: .cyan,
    ownerId: "u1", createdAt: fixtureNow, pinCount: 3, memberCount: 2, users: []
)

private let fixturePin = Pin(
    id: PinID("pin-0"),
    roomID: fixtureRoom.id,
    place: Place(
        id: PlaceID("place-0"), name: "패스트리 순간", address: "서울 성동구",
        coordinate: Coordinate(latitude: 37.5443, longitude: 127.0557), category: nil
    ),
    category: .worthVisiting,
    createdAt: fixtureNow
)

/// 이동 대상 조회 스텁. 성공/실패를 각각 지정한다.
private struct StubOpenDestination: FetchPinDetailUseCase, FetchRoomUseCase {
    var pin: Pin? = fixturePin
    var room: Room? = fixtureRoom

    func execute(pinID: PinID) async throws -> PinDetail {
        guard let pin else { throw DomainError.pinsFetchFailed }
        return PinDetail(pin: pin, sourceURL: nil)
    }

    func execute(id: String) async throws -> Room {
        guard let room else { throw DomainError.roomsFetchFailed }
        return room
    }
}

private struct StubFetchNotifications: FetchNotificationsUseCase {
    var firstResult: Result<Page<AppNotification>, DomainError> = .success(
        Page(items: [fixtureNotification(id: "0")], page: 0, pageSize: 20, hasNext: false)
    )
    var nextResult: Result<Page<AppNotification>, DomainError> = .success(
        Page(items: [], page: 1, pageSize: 20, hasNext: false)
    )

    func execute() async throws -> Page<AppNotification> {
        switch firstResult {
        case .success(let page): return page
        case .failure(let error): throw error
        }
    }

    func execute(next request: PageRequest) async throws -> Page<AppNotification> {
        switch nextResult {
        case .success(let page): return page
        case .failure(let error): throw error
        }
    }
}

@MainActor
struct NotificationListReducerTests {
    private func makeStore(
        _ useCase: FetchNotificationsUseCase = StubFetchNotifications(),
        state: NotificationListState = NotificationListState(),
        open: StubOpenDestination = StubOpenDestination()
    ) -> TestStore<NotificationListState, NotificationListAction, NotificationListNav> {
        TestStore(
            state,
            reduce: notificationListReducer(
                useCase: useCase, fetchPinDetail: open, fetchRoom: open, now: { fixtureNow }
            )
        )
    }

    private func loadedState(_ notifications: [AppNotification]) -> NotificationListState {
        NotificationListState(
            phase: .loaded,
            items: notifications.map { NotificationListItem(from: $0, now: fixtureNow) }
        )
    }

    @Test("L1 — load 하면 목록을 채우고 phase 를 loaded 로 바꾼다")
    func load_success() async {
        let page = Page(items: [fixtureNotification(id: "0")], page: 0, pageSize: 20, hasNext: false)
        let store = makeStore(StubFetchNotifications(firstResult: .success(page)))
        await store.send(.load)
        await store.receive(.loaded(page)) {
            $0.phase = .loaded
            $0.items = page.items.map { NotificationListItem(from: $0, now: fixtureNow) }
            $0.nextRequest = page.next
        }
        store.finish()
    }

    @Test("L1 — 0건 응답이면 빈 상태로 로드가 완료된다(UX-001 — 로딩 중엔 빈 상태 문구 금지)")
    func load_empty() async {
        let page = Page<AppNotification>(items: [], page: 0, pageSize: 20, hasNext: false)
        let store = makeStore(StubFetchNotifications(firstResult: .success(page)))
        await store.send(.load)
        await store.receive(.loaded(page)) {
            $0.phase = .loaded
            $0.items = []
        }
        store.finish()
    }

    @Test("L1 — load 실패 시 phase 가 failed 로 바뀐다")
    func load_failure() async {
        let store = makeStore(StubFetchNotifications(firstResult: .failure(.notificationsFetchFailed)))
        await store.send(.load)
        await store.receive(.loadFailed(.notificationsFetchFailed)) {
            $0.phase = .failed(.notificationsFetchFailed)
        }
        store.finish()
    }

    @Test("L2 — loadNext 는 기존 목록 뒤에 이어 붙인다(TS-037)")
    func loadNext_appends() async {
        let firstPage = Page(items: [fixtureNotification(id: "0")], page: 0, pageSize: 20, hasNext: true)
        let nextPage = Page(items: [fixtureNotification(id: "1")], page: 1, pageSize: 20, hasNext: false)
        let existingItems = firstPage.items.map { NotificationListItem(from: $0, now: fixtureNow) }
        let store = makeStore(
            StubFetchNotifications(firstResult: .success(firstPage), nextResult: .success(nextPage)),
            state: NotificationListState(phase: .loaded, items: existingItems, nextRequest: firstPage.next)
        )
        await store.send(.loadNext) { $0.isLoadingNext = true }
        await store.receive(.loadedNext(nextPage)) {
            $0.isLoadingNext = false
            $0.items = existingItems + nextPage.items.map { NotificationListItem(from: $0, now: fixtureNow) }
            $0.nextRequest = nextPage.next
        }
        store.finish()
    }

    @Test("L2 — loadNext 실패는 기존 목록을 유지한 채 loadNextFailed 만 세운다(EC-016 · TS-039)")
    func loadNext_failure_keepsExistingItems() async {
        let firstPage = Page(items: [fixtureNotification(id: "0")], page: 0, pageSize: 20, hasNext: true)
        let existingItems = firstPage.items.map { NotificationListItem(from: $0, now: fixtureNow) }
        let store = makeStore(
            StubFetchNotifications(nextResult: .failure(.notificationsFetchFailed)),
            state: NotificationListState(phase: .loaded, items: existingItems, nextRequest: firstPage.next)
        )
        await store.send(.loadNext) { $0.isLoadingNext = true }
        await store.receive(.loadNextFailed(.notificationsFetchFailed)) {
            $0.isLoadingNext = false
            $0.loadNextFailed = true
        }
        #expect(store.currentState.items == existingItems)
        store.finish()
    }

    @Test("L1 — 실패 배너가 떠 있는 동안 스크롤 트리거(loadNext)는 무시된다(요청 폭주 방지)")
    func loadNext_ignoredWhileFailureBannerShown() async {
        // LazyVStack 은 셀을 recycle 하므로 바닥에서 위아래로 움직이기만 해도 마지막 셀의
        // onAppear 가 반복 발화한다. 이 가드가 없으면 죽은 서버에 스크롤할 때마다 요청이 나간다.
        let firstPage = Page<AppNotification>(items: [], page: 0, pageSize: 20, hasNext: true)
        let store = makeStore(
            state: NotificationListState(
                phase: .loaded, items: [], nextRequest: firstPage.next, loadNextFailed: true
            )
        )
        await store.send(.loadNext)
        store.finish()
    }

    @Test("L2 — retryLoadNext 는 실패 플래그를 지우고 다시 요청한다")
    func retryLoadNext_clearsFailureAndRefetches() async {
        let firstPage = Page<AppNotification>(items: [], page: 0, pageSize: 20, hasNext: true)
        let nextPage = Page(items: [fixtureNotification(id: "1")], page: 1, pageSize: 20, hasNext: false)
        let store = makeStore(
            StubFetchNotifications(nextResult: .success(nextPage)),
            state: NotificationListState(
                phase: .loaded, items: [], nextRequest: firstPage.next, loadNextFailed: true
            )
        )
        await store.send(.retryLoadNext) {
            $0.loadNextFailed = false
            $0.isLoadingNext = true
        }
        await store.receive(.loadedNext(nextPage)) {
            $0.isLoadingNext = false
            $0.items = nextPage.items.map { NotificationListItem(from: $0, now: fixtureNow) }
            $0.nextRequest = nil
        }
        store.finish()
    }

    @Test("L1 — nextRequest 가 nil 이면 loadNext 는 아무 일도 하지 않는다(EC-018 · TS-038)")
    func loadNext_noNextRequest_noop() async {
        let store = makeStore(state: NotificationListState(phase: .loaded, items: [], nextRequest: nil))
        await store.send(.loadNext)
        store.finish()
    }

    @Test("L1 — 이미 isLoadingNext 인 동안 loadNext 재호출은 무시된다(스크롤 바운스 방어)")
    func loadNext_duplicateGuard() async {
        let firstPage = Page<AppNotification>(items: [], page: 0, pageSize: 20, hasNext: true)
        let store = makeStore(
            state: NotificationListState(
                phase: .loaded, items: [], nextRequest: firstPage.next, isLoadingNext: true
            )
        )
        await store.send(.loadNext)
        store.finish()
    }

    @Test("L1 — load 는 앱이 모르는 유형만 목록에서 거른다")
    func load_filtersUnknownType() async {
        let visible = fixtureNotification(id: "0")
        let page = Page(
            items: [visible, unknownTypeNotification(id: "1")],
            page: 0, pageSize: 20, hasNext: false
        )
        let store = makeStore(StubFetchNotifications(firstResult: .success(page)))
        await store.send(.load) { $0.phase = .loading }
        await store.receive(.loaded(page)) {
            $0.phase = .loaded
            $0.items = [NotificationListItem(from: visible, now: fixtureNow)]
            $0.nextRequest = page.next
        }
        store.finish()
    }

    // 문구는 서버가 완성해서 주므로 이동 대상이 없어도 셀 내용은 멀쩡하다 — 걸러 내면 서버가
    // 보낸 알림이 이유 없이 사라진다.
    @Test("L1 — 이동 대상 식별자가 없는 알림도 목록에 남는다")
    func load_keepsUnresolvedDestination() async {
        let unresolved = unresolvedNotification(id: "0")
        let page = Page(items: [unresolved], page: 0, pageSize: 20, hasNext: false)
        let store = makeStore(StubFetchNotifications(firstResult: .success(page)))
        await store.send(.load) { $0.phase = .loading }
        await store.receive(.loaded(page)) {
            $0.phase = .loaded
            $0.items = [NotificationListItem(from: unresolved, now: fixtureNow)]
            $0.nextRequest = page.next
        }
        store.finish()
    }

    @Test("L2 — 첫 장이 전부 걸러지고 다음 장이 있으면 자동으로 이어서 불러온다(무한스크롤 정지 방지)")
    func load_autoContinuesWhenPageFilteredEmpty() async {
        let firstPage = Page(items: [unknownTypeNotification(id: "0")], page: 0, pageSize: 20, hasNext: true)
        let secondPage = Page(items: [fixtureNotification(id: "1")], page: 1, pageSize: 20, hasNext: false)
        let store = makeStore(
            StubFetchNotifications(firstResult: .success(firstPage), nextResult: .success(secondPage))
        )
        await store.send(.load) { $0.phase = .loading }
        await store.receive(.loaded(firstPage)) {
            $0.phase = .loaded
            $0.items = []
            $0.nextRequest = firstPage.next
            $0.consecutiveEmptyPages = 1
        }
        await store.receive(.loadNext) { $0.isLoadingNext = true }
        await store.receive(.loadedNext(secondPage)) {
            $0.isLoadingNext = false
            $0.items = secondPage.items.map { NotificationListItem(from: $0, now: fixtureNow) }
            $0.nextRequest = secondPage.next
            $0.consecutiveEmptyPages = 0
        }
        store.finish()
    }

    @Test("L2 — loadNext 로 이어붙일 때 이미 있는 id 는 제외한다(오프셋 밀림 방어)")
    func loadNext_dedupesExistingIDs() async {
        let existingNotification = fixtureNotification(id: "0")
        let existingItems = [NotificationListItem(from: existingNotification, now: fixtureNow)]
        let duplicatePage = Page(
            items: [existingNotification, fixtureNotification(id: "1")], page: 1, pageSize: 20, hasNext: false
        )
        let store = makeStore(
            StubFetchNotifications(nextResult: .success(duplicatePage)),
            state: NotificationListState(
                phase: .loaded, items: existingItems, nextRequest: PageRequest(page: 1, pageSize: 20)
            )
        )
        await store.send(.loadNext) { $0.isLoadingNext = true }
        await store.receive(.loadedNext(duplicatePage)) {
            $0.isLoadingNext = false
            $0.items = existingItems + [NotificationListItem(from: fixtureNotification(id: "1"), now: fixtureNow)]
            $0.nextRequest = duplicatePage.next
        }
        store.finish()
    }

    @Test("L1 — 실패 상태에서 load 를 다시 보내면 즉시 loading 으로 바뀐다(재시도 버튼이 사라져 중복 탭을 막는다)")
    func load_retryFromFailed_setsLoadingImmediately() async {
        let store = makeStore(state: NotificationListState(phase: .failed(.notificationsFetchFailed)))
        await store.send(.load) { $0.phase = .loading }
        let page = Page(items: [fixtureNotification(id: "0")], page: 0, pageSize: 20, hasNext: false)
        await store.receive(.loaded(page)) {
            $0.phase = .loaded
            $0.items = page.items.map { NotificationListItem(from: $0, now: fixtureNow) }
        }
        store.finish()
    }

    @Test("L1 — 저장 오류 카드를 탭하면 저장 오류 안내로 navigate 한다(FR-010)")
    func tapNotification_saveError_navigates() async {
        let item = NotificationListItem(from: saveErrorNotification(id: "0"), now: fixtureNow)
        let store = makeStore(state: NotificationListState(phase: .loaded, items: [item]))
        await store.send(.tapNotification(item.id))
        store.receiveNavigation(.pushSaveError)
        store.finish()
    }

    @Test("L2 — 장소 알림을 탭하면 핀과 그 핀이 속한 방을 조회해 저장 탭으로 넘긴다")
    func tapNotification_place_resolvesPinAndRoom() async {
        let item = NotificationListItem(from: fixtureNotification(id: "0"), now: fixtureNow)
        let store = makeStore(state: loadedState([fixtureNotification(id: "0")]))

        await store.send(.tapNotification(item.id)) { $0.openingNotificationID = "0" }
        await store.receive(
            .openResolved(id: "0", destination: .place(pin: fixturePin, room: fixtureRoom))
        ) { $0.openingNotificationID = nil }
        store.receiveNavigation(.openCrossTab(.place(pin: fixturePin, room: fixtureRoom)))
        store.finish()
    }

    @Test("L2 — 방 알림을 탭하면 방을 조회해 저장 탭으로 넘긴다")
    func tapNotification_room_resolvesRoom() async {
        let store = makeStore(state: loadedState([roomNotification(id: "0")]))

        await store.send(.tapNotification("0")) { $0.openingNotificationID = "0" }
        await store.receive(.openResolved(id: "0", destination: .room(fixtureRoom))) {
            $0.openingNotificationID = nil
        }
        store.receiveNavigation(.openCrossTab(.room(fixtureRoom)))
        store.finish()
    }

    // 실패해도 탭을 옮기지 않는다 — 두 상세 화면이 완성된 객체를 필수로 받아서, 빈 화면으로
    // 넘어가려면 그 화면들이 로딩·실패 상태를 새로 표현해야 한다(조회 후 전환).
    @Test("L2 — 이동 대상 조회에 실패하면 탭에 머물고 스낵바 토큰만 올린다")
    func tapNotification_failure_staysOnTab() async {
        let store = makeStore(
            state: loadedState([roomNotification(id: "0")]),
            open: StubOpenDestination(room: nil)
        )

        await store.send(.tapNotification("0")) { $0.openingNotificationID = "0" }
        await store.receive(.openFailed(id: "0")) {
            $0.openingNotificationID = nil
            $0.openFailureToken = 1
        }
        store.finish()
    }

    @Test("L2 — 핀은 열렸는데 방 조회가 실패하면 이동하지 않는다")
    func tapNotification_placeWithoutRoom_fails() async {
        let store = makeStore(
            state: loadedState([fixtureNotification(id: "0")]),
            open: StubOpenDestination(room: nil)
        )

        await store.send(.tapNotification("0")) { $0.openingNotificationID = "0" }
        await store.receive(.openFailed(id: "0")) {
            $0.openingNotificationID = nil
            $0.openFailureToken = 1
        }
        store.finish()
    }

    // 조회가 끝나면 탭이 바뀐다. 그 사이 두 번째 목적지가 뒤따라 열리면 안 된다.
    @Test("L1 — 조회 중에는 다른 셀을 눌러도 받지 않는다")
    func tapNotification_whileOpening_ignoresOtherCells() async {
        var state = loadedState([fixtureNotification(id: "0"), roomNotification(id: "1")])
        state.openingNotificationID = "0"
        let store = makeStore(state: state)

        await store.send(.tapNotification("1"))
        store.finish()
    }

    // 저장 오류는 알림 탭 안 push 라 무해해 보이지만, 스택에 쌓인 채 저장 탭으로 넘어가면
    // 나중에 알림 탭으로 돌아왔을 때 목록이 아니라 그 화면이 떠 있다.
    @Test("L1 — 조회 중에는 저장 오류 셀도 막는다")
    func tapNotification_whileOpening_ignoresSaveErrorCell() async {
        var state = loadedState([fixtureNotification(id: "0"), saveErrorNotification(id: "1")])
        state.openingNotificationID = "0"
        let store = makeStore(state: state)

        await store.send(.tapNotification("1"))
        store.finish()
    }

    @Test("L1 — 이동 대상이 없는 알림을 탭해도 아무 일도 하지 않는다")
    func tapNotification_unresolved_noop() async {
        let store = makeStore(state: loadedState([unresolvedNotification(id: "0")]))

        await store.send(.tapNotification("0"))
        store.finish()
    }

    // 화면을 떠났다 돌아오는 사이 앞선 요청의 응답이 늦게 도착하면, 그때 시작된 이동을 덮어쓴다.
    @Test("L1 — 지금 조회 중인 알림의 응답이 아니면 버린다")
    func openResolved_staleResponseIsIgnored() async {
        var state = loadedState([fixtureNotification(id: "0"), roomNotification(id: "1")])
        state.openingNotificationID = "1"
        let store = makeStore(state: state)

        await store.send(.openResolved(id: "0", destination: .room(fixtureRoom)))
        await store.send(.openFailed(id: "0"))
        store.finish()
    }

    @Test("L1 — 스낵바는 토큰이 그대로일 때만 내려간다")
    func dismissOpenFailureToast_onlyForCurrentToken() async {
        let store = makeStore(state: NotificationListState(phase: .loaded, openFailureToken: 2))

        await store.send(.dismissOpenFailureToast(1))   // 앞선 스낵바의 타이머 — 무시된다
        await store.send(.dismissOpenFailureToast(2)) { $0.openFailureToken = 0 }
        store.finish()
    }

    @Test("L1 — 목록에 없는 id 를 탭하면 아무 일도 하지 않는다")
    func tapNotification_unknownID_noop() async {
        let store = makeStore(state: NotificationListState(phase: .loaded, items: []))
        await store.send(.tapNotification("no-such-id"))
        store.finish()
    }

    @Test("L1 — load 성공은 이전 loadNextFailed/isLoadingNext 잔여 플래그를 초기화한다")
    func load_success_resetsStaleLoadNextFlags() async {
        let store = makeStore(
            state: NotificationListState(phase: .failed(.notificationsFetchFailed), loadNextFailed: true)
        )
        await store.send(.load) { $0.phase = .loading }
        let page = Page(items: [fixtureNotification(id: "0")], page: 0, pageSize: 20, hasNext: false)
        await store.receive(.loaded(page)) {
            $0.phase = .loaded
            $0.items = page.items.map { NotificationListItem(from: $0, now: fixtureNow) }
            $0.loadNextFailed = false
        }
        store.finish()
    }

    @Test("L2 — 걸러진 빈 장이 두 번 연속이어도 세 번째 장에서 정상 종료한다(다단 자동 이어받기)")
    func load_autoContinuesAcrossMultipleFilteredPages() async {
        let firstPage = Page(items: [unknownTypeNotification(id: "0")], page: 0, pageSize: 20, hasNext: true)
        let secondPage = Page(items: [unknownTypeNotification(id: "1")], page: 1, pageSize: 20, hasNext: true)
        let thirdPage = Page(items: [fixtureNotification(id: "2")], page: 2, pageSize: 20, hasNext: false)

        struct MultiHopFetch: FetchNotificationsUseCase {
            let firstPage: Page<AppNotification>
            let pagesByRequestPage: [Int: Page<AppNotification>]
            func execute() async throws -> Page<AppNotification> { firstPage }
            func execute(next request: PageRequest) async throws -> Page<AppNotification> {
                pagesByRequestPage[request.page]!
            }
        }

        let store = makeStore(
            MultiHopFetch(firstPage: firstPage, pagesByRequestPage: [1: secondPage, 2: thirdPage])
        )
        await store.send(.load) { $0.phase = .loading }
        await store.receive(.loaded(firstPage)) {
            $0.phase = .loaded
            $0.items = []
            $0.nextRequest = firstPage.next
            $0.consecutiveEmptyPages = 1
        }
        await store.receive(.loadNext) { $0.isLoadingNext = true }
        await store.receive(.loadedNext(secondPage)) {
            $0.isLoadingNext = false
            $0.items = []
            $0.nextRequest = secondPage.next
            $0.consecutiveEmptyPages = 2
        }
        await store.receive(.loadNext) { $0.isLoadingNext = true }
        await store.receive(.loadedNext(thirdPage)) {
            $0.isLoadingNext = false
            $0.items = thirdPage.items.map { NotificationListItem(from: $0, now: fixtureNow) }
            $0.nextRequest = thirdPage.next
            $0.consecutiveEmptyPages = 0
        }
        store.finish()
    }

    @Test("L2 — 서버가 같은 장을 계속 돌려줘도 자동 이어받기는 상한에서 멈춘다(요청 폭주 방지)")
    func load_autoContinueStopsAtCap() async {
        // 요청한 장을 무시하고 늘 같은 내용 + hasNext:true 를 주는 서버. 중복 제거로 매번 0건이라
        // 상한이 없으면 응답이 다음 요청을 스스로 불러 끝없이 반복된다.
        let stuckPage = Page(items: [fixtureNotification(id: "0")], page: 0, pageSize: 20, hasNext: true)

        struct StuckServerFetch: FetchNotificationsUseCase {
            let page: Page<AppNotification>
            func execute() async throws -> Page<AppNotification> { page }
            func execute(next request: PageRequest) async throws -> Page<AppNotification> { page }
        }

        let store = makeStore(StuckServerFetch(page: stuckPage))
        let onlyItem = [NotificationListItem(from: fixtureNotification(id: "0"), now: fixtureNow)]

        await store.send(.load) { $0.phase = .loading }
        // 첫 장은 실제로 1건을 보태므로 헛돈 것이 아니다 — streak 은 0 을 유지하고 자동 이어받기도 없다.
        await store.receive(.loaded(stuckPage)) {
            $0.phase = .loaded
            $0.items = onlyItem
            $0.nextRequest = stuckPage.next
        }

        // 사용자가 목록 끝에 닿아 한 번 요청한 뒤로는 서버가 같은 장만 준다.
        await store.send(.loadNext) { $0.isLoadingNext = true }
        for streak in 1..<maxConsecutiveEmptyPagesForTest {
            await store.receive(.loadedNext(stuckPage)) {
                $0.isLoadingNext = false
                $0.consecutiveEmptyPages = streak
            }
            await store.receive(.loadNext) { $0.isLoadingNext = true }
        }

        // 상한에 닿는 응답에서 자동 이어받기가 끊기고, 재시도를 사용자에게 넘긴다.
        await store.receive(.loadedNext(stuckPage)) {
            $0.isLoadingNext = false
            $0.consecutiveEmptyPages = maxConsecutiveEmptyPagesForTest
            $0.loadNextFailed = true
        }

        #expect(store.currentState.items == onlyItem)   // 기존 목록은 그대로 유지된다
        store.finish()                                   // 더 이상 발사되는 effect 가 없다
    }
}
