import Domain
import Foundation
import MVI

/// 알림 목록 화면 상태. `phase`(초기 로딩/로드 완료/전체 실패) + 추가 로드 플래그 조합.
/// [Convention] .claude/docs/mvi-coordinator-di.md §2 — "에러를 State 에 담는 모양은 화면마다 결정,
/// 강제 규칙 아님". `phase` 는 초기 로딩·목록·전체 실패 3종을 배타적으로 나누고, "추가 로드 실패"는
/// 기존 목록을 유지한 채 얹히는 오버레이 상태라 별도 플래그로 둔다.
public struct NotificationListState: Equatable {
    public enum Phase: Equatable {
        case loading
        case loaded
        case failed(DomainError)
    }

    public var phase: Phase
    public var items: [NotificationListItem]
    /// 다음 페이지 요청. `Page.next` 를 그대로 저장 — nil 이면 더 불러올 장이 없다(EC-018).
    public var nextRequest: PageRequest?
    /// 스크롤 바운스로 `.loadNext` 가 짧은 시간에 여러 번 불려도 중복 요청을 막는 가드.
    public var isLoadingNext: Bool
    public var loadNextFailed: Bool
    /// 자동 이어받기가 연속으로 헛돈 횟수 — 화면에 보탤 항목이 0개인 장을 몇 번 내리 받았는가.
    /// 사용자 조작 없이 요청이 반복되는 유일한 경로라 상한이 필요하다(`maxConsecutiveEmptyPages`).
    public var consecutiveEmptyPages: Int

    public init(
        phase: Phase = .loading,
        items: [NotificationListItem] = [],
        nextRequest: PageRequest? = nil,
        isLoadingNext: Bool = false,
        loadNextFailed: Bool = false,
        consecutiveEmptyPages: Int = 0
    ) {
        self.phase = phase
        self.items = items
        self.nextRequest = nextRequest
        self.isLoadingNext = isLoadingNext
        self.loadNextFailed = loadNextFailed
        self.consecutiveEmptyPages = consecutiveEmptyPages
    }
}

public enum NotificationListAction: Equatable {
    case load
    case loaded(Page<AppNotification>)
    case loadFailed(DomainError)
    case loadNext
    /// 실패 배너의 "다시 시도" — 스크롤 트리거(`loadNext`)와 갈라 둔다(아래 `loadNext` 주석).
    case retryLoadNext
    case loadedNext(Page<AppNotification>)
    case loadNextFailed(DomainError)
    case tapNotification(NotificationListItem.ID)
}

public enum NotificationListNav: Equatable, Sendable {
    /// 저장 오류 알림 카드를 탭했을 때(FR-010) — 어느 카드를 눌러도 같은 화면이라 연관값이 없다(EC-013).
    case pushSaveError
}

public typealias NotificationListStore = Store<NotificationListState, NotificationListAction, NotificationListNav>

/// 순수 reduce. 의존성(UseCase)은 `Effect.run` 안에서만 사용하고 시그니처는 순수하게 유지한다.
/// [Convention] .claude/docs/mvi-coordinator-di.md §5 — reduce 는 UseCase 를 받는다.
public func notificationListReducer(
    useCase: FetchNotificationsUseCase,
    now: @escaping () -> Date = Date.init
) -> (inout NotificationListState, NotificationListAction) -> Effect<NotificationListAction, NotificationListNav> {
    { state, action in
        switch action {
        case .load:
            // 재진입 방어: phase 를 즉시 .loading 으로 바꿔 재시도 버튼을 화면에서 없앤다
            // (버튼이 사라지므로 응답 오기 전 중복 탭 자체가 불가능해진다).
            state.phase = .loading
            state.consecutiveEmptyPages = 0
            return .run { send in
                do {
                    let page = try await useCase.execute()
                    send(.loaded(page))
                } catch let error as DomainError {
                    send(.loadFailed(error))
                } catch {
                    send(.loadFailed(.unknown))
                }
            }

        case .loaded(let page):
            state.phase = .loaded
            state.items = mapItems(page.items, now: now())
            state.nextRequest = page.next
            // 재조회이므로 이전 추가 로드 상태는 무의미해진 값 — 남아있으면 방금 받은 새 목록 아래에
            // 근거 없는 재시도 배너가 붙는다.
            state.isLoadingNext = false
            state.loadNextFailed = false
            return continueIfNothingNew(&state, newItems: state.items)

        case .loadFailed(let error):
            state.phase = .failed(error)
            return .none

        case .loadNext:
            // 실패 배너가 떠 있는 동안은 스크롤 트리거를 무시한다. LazyVStack 은 셀을 recycle 하므로
            // 바닥에서 위아래로 움직이기만 해도 마지막 셀의 onAppear 가 반복 발화하는데, 그대로
            // 두면 죽은 서버에 스크롤할 때마다 요청이 나가고 배너도 깜빡인다. 재시도는 사용자가
            // 버튼을 누를 때(`retryLoadNext`)만 나간다.
            guard !state.loadNextFailed else { return .none }
            return startLoadNext(&state, useCase: useCase)

        case .retryLoadNext:
            state.loadNextFailed = false
            return startLoadNext(&state, useCase: useCase)

        case .loadedNext(let page):
            // id 기준 중복 제거 — 서버 오프셋 페이징 중 새 알림이 앞에 끼어들면 경계가 밀려
            // 같은 항목이 두 장에 걸쳐 올 수 있다(Domain.Page 문서가 명시한 소비자 책임).
            let existingIDs = Set(state.items.map(\.id))
            let newItems = mapItems(page.items, now: now()).filter { !existingIDs.contains($0.id) }
            state.isLoadingNext = false
            state.loadNextFailed = false
            state.items += newItems
            state.nextRequest = page.next
            return continueIfNothingNew(&state, newItems: newItems)

        case .loadNextFailed:
            // 기존 목록은 그대로 두고 목록 끝의 재시도 표시만 세운다(EC-016 · TS-039).
            state.isLoadingNext = false
            state.loadNextFailed = true
            return .none

        case .tapNotification(let id):
            guard let item = state.items.first(where: { $0.id == id }) else { return .none }
            switch item.destination {
            case .saveError:
                return .navigate(.pushSaveError)
            case .place, .room:
                // 탭 밖 이동은 이번 PR 범위 밖([SYS-004] 없음) — 아무 일도 하지 않는다.
                return .none
            }
        }
    }
}

/// 다음 장 요청을 띄운다. 이미 진행 중이거나(스크롤 바운스 방어) 더 불러올 장이 없으면(EC-018)
/// 아무 일도 하지 않는다.
private func startLoadNext(
    _ state: inout NotificationListState,
    useCase: FetchNotificationsUseCase
) -> Effect<NotificationListAction, NotificationListNav> {
    guard let request = state.nextRequest, !state.isLoadingNext else { return .none }
    state.isLoadingNext = true
    state.loadNextFailed = false
    return .run { send in
        do {
            let page = try await useCase.execute(next: request)
            send(.loadedNext(page))
        } catch let error as DomainError {
            send(.loadNextFailed(error))
        } catch {
            send(.loadNextFailed(.unknown))
        }
    }
}

/// 자동 이어받기 연속 상한. 한 장이 20건이므로, 이만큼 내리 받아도 화면에 보탤 항목이 하나도
/// 없다면 데이터가 아니라 계약이 어긋난 상황으로 본다.
private let maxConsecutiveEmptyPages = 5

/// 방금 받은 장에서 화면에 보탤 항목이 0개인데 다음 장이 남아 있으면 `.loadNext` 를 한 번 더 보낸다.
/// 그대로 두면 목록 마지막 셀의 `onAppear` 트리거가 새로 생기지 않아 무한스크롤이 조용히 멈춘다
/// (첫 장이면 빈 화면에 영구 고착). 필터로 전부 빠진 경우와 중복 제거로 전부 빠진 경우 둘 다다.
///
/// **상한이 여기에만 필요하다.** 다른 요청은 사용자 조작이 하나씩 일으키지만 이 경로는 응답이
/// 다음 요청을 스스로 부른다. 서버가 요청한 장을 무시하거나 마지막 장으로 clamp 한 채 `hasNext` 를
/// 계속 true 로 주면(계약이 잠정이라 배제할 수 없다) 매번 0건이 되어 요청이 끝없이 반복된다.
/// `Page.page` 를 요청값으로 바꾸는 걸로는 부족하다 — 번호만 올라갈 뿐 종료 조건은 서버가 쥔다.
///
/// 상한에 걸리면 조용히 멈추지 않고 `loadNextFailed` 를 세워 화면이 재시도를 내밀게 한다.
/// 재시도는 누를 때마다 한 번씩만 나간다(상한이 이미 차 있어 곧바로 다시 걸린다).
private func continueIfNothingNew(
    _ state: inout NotificationListState,
    newItems: [NotificationListItem]
) -> Effect<NotificationListAction, NotificationListNav> {
    guard newItems.isEmpty else {
        state.consecutiveEmptyPages = 0
        return .none
    }
    guard state.nextRequest != nil else { return .none }   // 더 볼 장이 없다 — 빈 상태 화면이 받는다

    state.consecutiveEmptyPages += 1
    guard state.consecutiveEmptyPages < maxConsecutiveEmptyPages else {
        state.loadNextFailed = true
        return .none
    }
    return .run { send in send(.loadNext) }
}

/// `.unknown` 유형(서버 유형 문자열 계약이 아직 확정되지 않았다)과 `.unresolved` payload
/// (Data 레이어가 표시값을 못 뽑아 이미 "표시 불가"로 판정한 것)는 목록에 담기지 않는다. 이 둘을
/// 그대로 통과시키면 Data 가 세운 방어가 화면에서 무력화돼 "님이 들어왔어요" 같은 깨진 셀이 보인다.
private func mapItems(_ notifications: [AppNotification], now: Date) -> [NotificationListItem] {
    notifications
        .filter {
            if case .unknown = $0.type { return false }
            if case .unresolved = $0.payload { return false }
            return true
        }
        .map { NotificationListItem(from: $0, now: now) }
}
