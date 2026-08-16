import SwiftUI
import UIKit

extension View {
    /// nav bar 를 숨긴 화면(공동방 만들기 등)에서도 엣지 백스와이프 pop 이 동작하게 한다.
    ///
    /// SwiftUI 는 `.toolbar(.hidden, for: .navigationBar)` 로 내비바를 숨기면
    /// `interactivePopGestureRecognizer` 를 비활성화한다. 이 헬퍼가 그 제스처의 delegate 를
    /// 되살려, 스택에 뒤 화면이 남아 있을 때(= pop 가능할 때) 엣지 스와이프 pop 을 허용한다.
    func enablesBackSwipe() -> some View {
        background(BackSwipeEnabler())
    }
}

private struct BackSwipeEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { Proxy() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    /// 스택의 UINavigationController 를 찾아 pop 제스처를 되살리는 얇은 프록시 컨트롤러.
    final class Proxy: UIViewController, UIGestureRecognizerDelegate {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            guard let pop = navigationController?.interactivePopGestureRecognizer else { return }
            pop.delegate = self
            pop.isEnabled = true
        }

        // 루트에서의 스와이프로 hang 이 나지 않게, 뒤 화면이 있을 때만 제스처를 시작한다.
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}
