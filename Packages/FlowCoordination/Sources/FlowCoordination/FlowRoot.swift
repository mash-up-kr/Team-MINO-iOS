import SwiftUI

public extension View {
    /// 시트/풀스크린 커버의 루트 뷰에 붙여 `coordinator.finish` 에 진짜 dismiss 액션을 연결한다.
    /// `onFinish` 는 자식 flow 가 발사한 output 을 시트를 띄운 쪽에서 받기 위한 콜백이다.
    ///
    /// 결과 처리 컨벤션: `onFinish` 본문에 비즈니스 로직을 직접 쓰지 않고
    /// **부모 Coordinator 의 메서드로 한 줄 위임**한다.
    ///
    /// ```swift
    /// .flowRoot(editCoordinator) { result in
    ///     coordinator.editDidFinish(result)
    /// }
    /// ```
    func flowRoot<C: Coordinator>(
        _ coordinator: C,
        onFinish: @escaping (C.Output) -> Void = { _ in }
    ) -> some View {
        modifier(FlowRootModifier(coordinator: coordinator, onFinish: onFinish))
    }
}

private struct FlowRootModifier<C: Coordinator>: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let coordinator: C
    let onFinish: (C.Output) -> Void

    func body(content: Content) -> some View {
        // bind 는 사용자 인터랙션(finish 발사: 저장/취소 버튼 탭)보다 항상 먼저다 —
        // 화면이 떠야(onAppear) 사용자가 누를 수 있으므로 race 가 없다(.task 와의 선후가 아니라 이게 안전 근거).
        // 시트가 여러 번 present/dismiss 되면 onAppear 가 반복돼 bind 가 재실행되지만,
        // FlowFinish.didFire 가 1회성을 유지한다 (FlowFinishTests.rebind_replaces_action_but_keeps_one_shot).
        content.onAppear {
            coordinator.finish.bind { output in
                onFinish(output)
                dismiss()
            }
        }
    }
}
