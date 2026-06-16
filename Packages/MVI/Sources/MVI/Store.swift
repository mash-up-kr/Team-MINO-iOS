import Foundation
import Observation

/// 화면 단위의 단방향 상태 컨테이너.
///
/// 세 축이 여기로 수렴한다: (1) 주입받은 의존성을 묶은 순수 `reduce`, (2) 경량 A 의 `Effect` 실행,
/// (3) `navigationEffects` 로 화면 전환 의도를 Coordinator 에 전달.
/// reduce 는 순수하게 `Effect` 값만 반환하고, Store 가 그 Effect 를 실행한다.
@Observable
@MainActor
public final class Store<State, Action, Nav: Sendable> {
    public private(set) var state: State

    /// Coordinator 가 `for await` 로 구독하는 화면 전환 채널.
    public let navigationEffects: AsyncStream<Nav>
    private let navContinuation: AsyncStream<Nav>.Continuation

    private let reduce: (inout State, Action) -> Effect<Action, Nav>
    // 진행 중인 run effect 들. 완료되면 자기 자신을 제거해 누적되지 않는다.
    // 변경은 항상 @MainActor 에서만 일어나고, 읽기는 deinit(해제 시점, 경쟁 없음)에서만 한다.
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
                await operation { action in self?.send(action) }
                self?.tasks[id] = nil   // 완료 시 자기 자신 제거
            }
        }
    }
}
