import Foundation
import Testing
import MVI

/// 경량 A 의 자체 L1~L3 TestStore (실용형).
///
/// reduce 를 결정적으로 검증한다. `send`(내가 보낸 action) → `receive`(effect 가 되돌린 action)
/// → `finish`(잔여 검증) 3박자에, navigation 채널(`receiveNavigation`)을 더한 형태다.
/// 의존성(useCase 등)은 mock 으로 즉답시켜 시간 의존을 제거한다.
///
/// - L1: 순수 reduce 상태 전이 (send 의 expect)
/// - L2: 비동기 Effect 시나리오 (run → pending → receive)
/// - L3: exhaustive — 단언 안 한 state 변화 / 미수신 effect·navigation 을 자동 실패
@MainActor
public final class TestStore<State: Equatable, Action: Equatable, Nav: Equatable> {
    private var state: State
    private let reduce: (inout State, Action) -> Effect<Action, Nav>
    private var pending: [Action] = []          // effect 가 보낸, 아직 안 받은 action
    private var navs: [Nav] = []                 // 발생한, 아직 단언 안 한 navigation

    /// L3 엄격성 on/off.
    /// - true: 단언하지 않은 state 변화·미수신 effect/navigation 을 자동 실패시킨다.
    /// - false: 중간 state 단언과 finish 잔여 검사를 끈다 — 최종은 `currentState` 로 직접 확인한다.
    ///   (`receive` 의 action 매칭은 exhaustive 와 무관하게 항상 동작한다.)
    public var exhaustive = true

    public init(
        _ initial: State,
        reduce: @escaping (inout State, Action) -> Effect<Action, Nav>
    ) {
        self.state = initial
        self.reduce = reduce
    }

    /// 현재 state (exhaustive 를 끄고 최종만 직접 확인할 때 사용).
    public var currentState: State { state }

    /// 내가 보내는 action: 동기 변화 단언 + effect 적재.
    public func send(
        _ action: Action,
        expect: (inout State) -> Void = { _ in },
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        var expected = state
        expect(&expected)
        let effect = reduce(&state, action)
        assertState(expected, sourceLocation: sourceLocation)
        await drain(effect)
    }

    /// effect 가 되돌린 action: pending 에서 찾아 처리 + 단언.
    public func receive(
        _ action: Action,
        expect: (inout State) -> Void = { _ in },
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        guard let index = pending.firstIndex(of: action) else {
            Issue.record("기대한 effect action 없음: \(action)", sourceLocation: sourceLocation)
            return
        }
        pending.remove(at: index)
        var expected = state
        expect(&expected)
        let effect = reduce(&state, action)
        assertState(expected, sourceLocation: sourceLocation)
        await drain(effect)
    }

    /// reduce 가 보낸 navigation 의도를 단언한다.
    public func receiveNavigation(
        _ nav: Nav,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        guard let index = navs.firstIndex(of: nav) else {
            Issue.record("기대한 navigation 없음: \(nav)", sourceLocation: sourceLocation)
            return
        }
        navs.remove(at: index)
    }

    /// 마무리: 안 받은 effect action / navigation 이 남으면 실패.
    public func finish(sourceLocation: SourceLocation = #_sourceLocation) {
        guard exhaustive else { return }
        if !pending.isEmpty {
            Issue.record("미처리 effect 남음: \(pending)", sourceLocation: sourceLocation)
        }
        if !navs.isEmpty {
            Issue.record("미처리 navigation 남음: \(navs)", sourceLocation: sourceLocation)
        }
    }

    private func drain(_ effect: Effect<Action, Nav>) async {
        switch effect {
        case .none:
            break
        case .navigate(let nav):
            navs.append(nav)
        case .run(let operation):
            await operation { [weak self] action in self?.pending.append(action) }
        }
    }

    private func assertState(_ expected: State, sourceLocation: SourceLocation) {
        guard exhaustive, state != expected else { return }
        Issue.record("state 불일치:\n\(fieldDiff(expected, state))", sourceLocation: sourceLocation)
    }
}

/// 두 값의 다른 필드만 추려 보여주는 진단 헬퍼 (Mirror 기반).
func fieldDiff<T>(_ expected: T, _ actual: T) -> String {
    let em = Mirror(reflecting: expected)
    let am = Mirror(reflecting: actual)
    guard !em.children.isEmpty else {
        return "expected: \(expected)\nactual:   \(actual)"
    }
    var lines: [String] = []
    for (e, a) in zip(em.children, am.children) {
        let label = e.label ?? "?"
        if "\(e.value)" != "\(a.value)" {
            lines.append("  \(label): expected \(e.value) / actual \(a.value)")
        }
    }
    return lines.isEmpty ? "expected: \(expected)\nactual:   \(actual)" : lines.joined(separator: "\n")
}
