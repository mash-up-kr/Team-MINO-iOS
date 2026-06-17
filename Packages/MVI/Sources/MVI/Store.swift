import Foundation
import Observation

/// 화면 단위의 단방향 상태 컨테이너.
///
/// 세 축이 여기로 수렴한다: (1) 주입받은 의존성을 묶은 순수 `reduce`, (2) 경량 A 의 `Effect` 실행,
/// (3) `observeNavigation(_:)` 으로 화면 전환 의도를 Coordinator 에 전달.
/// reduce 는 순수하게 `Effect` 값만 반환하고, Store 가 그 Effect 를 실행한다.
@Observable
@MainActor
public final class Store<State, Action, Nav: Sendable> {
    public private(set) var state: State

    // 화면 전환 채널. raw 노출 대신 observeNavigation(_:) 으로만 구독시켜 단일 소비자를 보장한다.
    private let navigationEffects: AsyncStream<Nav>
    private let navContinuation: AsyncStream<Nav>.Continuation
    private var navObserved = false

    private let reduce: (inout State, Action) -> Effect<Action, Nav>
    // 진행 중인 run effect 들. 완료되면 자기 자신을 제거해 누적되지 않는다.
    // 쓰기는 @MainActor, 읽기는 nonisolated deinit. @MainActor 객체(View @State 소유)라
    // MainActor 에서 해제된다는 가정 위에서 race-free 이다(보장은 아님; Swift 6.1 isolated deinit 으로 정리 가능).
    @ObservationIgnored nonisolated(unsafe) private var tasks: [UUID: Task<Void, Never>] = [:]

    public init(
        _ initial: State,
        reduce: @escaping (inout State, Action) -> Effect<Action, Nav>
    ) {
        self.state = initial
        self.reduce = reduce
        (navigationEffects, navContinuation) = AsyncStream.makeStream()
    }

    deinit {
        tasks.values.forEach { $0.cancel() }
        navContinuation.finish()
    }

    /// 화면 전환 의도를 구독한다. Coordinator 가 store 생성 직후 한 번 호출한다.
    /// 구독 Task 는 store 의 tasks 로 관리되어 store 수명과 함께 정리된다(별도 effectTasks 불필요).
    public func observeNavigation(_ handler: @escaping @MainActor (Nav) -> Void) {
        guard !navObserved else {
            // 단일 소비자 위반: 디버그에선 잡고, 릴리스에선 두 번째 호출을 무시해 기존 구독을 유지한다(크래시 회피).
            assertionFailure("navigationEffects 는 단일 소비자입니다 (observeNavigation 중복 호출)")
            return
        }
        navObserved = true
        let id = UUID()
        let stream = navigationEffects
        tasks[id] = Task { [weak self] in
            defer { self?.tasks[id] = nil }
            for await nav in stream { handler(nav) }
        }
    }

    public func send(_ action: Action) {
        // Log.debug("Action: \(action)")   // 미들웨어 1곳 (사건 로그) — 전역 로거 도입 시 활성화
        execute(reduce(&state, action))
    }

    private func execute(_ effect: Effect<Action, Nav>) {
        switch effect {
        case .none:
            break
        case .navigate(let nav):
            navContinuation.yield(nav)
        case .run(let operation):
            let id = UUID()
            tasks[id] = Task { [weak self] in
                defer { self?.tasks[id] = nil }   // 모든 종료 경로에서 정리
                await operation { action in self?.send(action) }
            }
        }
    }
}
