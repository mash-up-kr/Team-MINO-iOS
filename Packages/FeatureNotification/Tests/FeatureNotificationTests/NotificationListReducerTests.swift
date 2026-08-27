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
        payload: .place(name: "연남동 스탠딩 커피", imageURL: nil, placeID: nil),
        createdAt: createdAt
    )
}

// payload 는 일부러 resolved 인 `.place` 로 둔다 — `.unresolved` 를 함께 쓰면 `.unknown` 필터
// 줄을 지워도 `.unresolved` 필터에 걸려 통과해, `.unknown` 필터를 실제로 검증하지 못하게 된다.
private func unknownTypeNotification(id: String) -> AppNotification {
    AppNotification(
        id: NotificationID(id), type: .unknown(raw: "future_type"),
        payload: .place(name: "무관", imageURL: nil, placeID: nil), createdAt: fixtureNow
    )
}

private func unresolvedPayloadNotification(id: String) -> AppNotification {
    AppNotification(id: NotificationID(id), type: .memberJoined, payload: .unresolved, createdAt: fixtureNow)
}

private func saveErrorNotification(id: String) -> AppNotification {
    AppNotification(id: NotificationID(id), type: .saveError, payload: .saveError, createdAt: fixtureNow)
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
        state: NotificationListState = NotificationListState()
    ) -> TestStore<NotificationListState, NotificationListAction, NotificationListNav> {
        TestStore(state, reduce: notificationListReducer(useCase: useCase, now: { fixtureNow }))
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

    @Test("L1 — load 는 .unknown 유형과 .unresolved payload 를 목록에서 거른다")
    func load_filtersUnknownAndUnresolved() async {
        let visible = fixtureNotification(id: "0")
        let page = Page(
            items: [visible, unknownTypeNotification(id: "1"), unresolvedPayloadNotification(id: "2")],
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

    @Test("L1 — 장소·방 알림을 탭해도 아무 일도 하지 않는다(탭 밖 이동은 범위 밖)")
    func tapNotification_placeOrRoom_noop() async {
        let item = NotificationListItem(from: fixtureNotification(id: "0"), now: fixtureNow)
        let store = makeStore(state: NotificationListState(phase: .loaded, items: [item]))
        await store.send(.tapNotification(item.id))
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
        let secondPage = Page(items: [unresolvedPayloadNotification(id: "1")], page: 1, pageSize: 20, hasNext: true)
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
