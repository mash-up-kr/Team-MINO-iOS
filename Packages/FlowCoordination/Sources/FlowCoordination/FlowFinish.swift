import Foundation

/// 자식 Coordinator 가 부모에게 결과를 **1회** 보고하는 표준 채널.
///
/// 화면 전환 의도(NavigationEffect)와는 별개의 "flow 종료" 신호다.
/// 부모가 `flowRoot(_:onFinish:)` 에서 `bind` 로 연결하고, 자식은
/// `finish(output)` 으로 발사한다. 취소/완료 구분은 `Output` 타입(보통 enum)으로 표현한다.
///
/// 핵심 특성:
/// - `callAsFunction` 으로 `coordinator.finish(output)` / `coordinator.finish()`(Void) 호출
/// - `bind(_:)` 로 시트 루트가 dismiss 액션을 주입
/// - 한 번 발사되면 이중 실행을 방어한다(시트가 닫히는 도중 추가 탭 등 재진입 방지)
@MainActor
public final class FlowFinish<Output> {
    private var action: ((Output) -> Void)?
    private var didFire = false

    public init() {}

    /// 시트 루트(`flowRoot`)에서 호출. 이미 bind 된 적이 있으면 새 action 으로 교체되고 발사 상태도 초기화된다.
    public func bind(_ action: @escaping (Output) -> Void) {
        self.action = action
        didFire = false
    }

    /// flow 종료를 트리거한다. 같은 인스턴스에서 이미 발사됐다면 무시한다.
    public func callAsFunction(_ output: Output) {
        guard !didFire else { return }
        didFire = true
        action?(output)
    }

    /// 동일 Coordinator 를 재사용하는 테스트 등에서 발사 상태를 리셋한다.
    public func reset() {
        didFire = false
    }
}

public extension FlowFinish where Output == Void {
    /// `coordinator.finish()` 형태로 호출할 수 있게 하는 Void 전용 오버로드.
    func callAsFunction() { self(()) }
}
