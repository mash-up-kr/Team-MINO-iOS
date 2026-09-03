import Foundation

/// 경량 A(MVI)에서 reduce 가 반환하는 부수효과 값.
///
/// reduce 는 순수 함수로서 부수효과를 **직접 실행하지 않고** 이 값으로 표현해 반환한다.
/// 실제 실행(비동기 Task, navigation yield)은 `Store` 가 맡는다.
/// - `none`: 부수효과 없음
/// - `run`: 비동기 작업. 완료 시 결과를 Response Action 으로 다시 `send` 한다.
/// - `navigate`: 화면 전환 의도. `Store` 가 `navigationEffects` 로 흘려보내 Coordinator 가 구독한다.
public enum Effect<Action, Nav> {
    case none
    case run(@MainActor (_ send: @MainActor @escaping (Action) -> Void) async -> Void)
    case navigate(Nav)
}
