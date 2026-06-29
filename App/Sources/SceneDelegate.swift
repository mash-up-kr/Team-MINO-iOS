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
    }
}
