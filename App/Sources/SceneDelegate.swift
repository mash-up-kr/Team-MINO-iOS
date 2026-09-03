import UIKit

/// SwiftUI App lifecycle 이 window 와 rootView 를 관리하므로,
/// 여기서는 scene 단위 진입 훅(딥링크·단축어·상태 복원 등)만 다룬다. (현재는 자리만)
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // SwiftUI(MINOApp)가 rootView 를 구성한다. 추가 진입 처리는 여기에.
        //
        // ⚠️ 딥링크는 여기서 받지 않는다 — `MINOApp` 의 `.onOpenURL` 이 받는다.
        //    이 타입에 `scene(_:openURLContexts:)` 를 구현하는 순간 SwiftUI 가 URL 전달을
        //    그쪽으로 넘겨, `.onOpenURL` 이 에러 없이 조용히 안 불리게 된다.
    }
}
