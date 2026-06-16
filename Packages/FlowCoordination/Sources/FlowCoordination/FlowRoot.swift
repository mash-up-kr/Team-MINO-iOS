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
        // .onAppear 는 .task 보다 동기적으로 더 빨리 실행되어 bind 누락 위험을 줄인다.
        content.onAppear {
            coordinator.finish.bind { output in
                onFinish(output)
                dismiss()
            }
        }
    }
}
