import Core
import LinkPresentation
import SwiftUI
import UIKit

/// 튜토리얼 3단계에서 띄우는 **실제 iOS 공유시트**(`UIActivityViewController`).
///
/// 공유하는 내용 자체는 쓰이지 않는다 — 목적은 사용자가 시트에서 우리 앱을 한 번 눌러보게 하는 것이다.
/// 그래서 헤더에 안내 문구를 제목으로 얹고, 실제 공유 아이템은 최소한만 넘긴다.
///
/// > Figma(`2314:58969`)의 부제 "여러 앱 중 '꾹'을 찾아 눌러주세요." 와 셰브론은 넣을 수 없다.
/// > `LPLinkMetadata` 에 부제 필드가 없고 그 자리는 `originalURL` 의 도메인이 자동으로 채운다.
/// > 셰브론은 iCloud 공동작업 공유 전용이다.
/// SwiftUI `.sheet` 로 감싸지 않고 UIKit 이 직접 present 한다 — `.sheet` 안에 넣으면
/// 공유시트가 SwiftUI 시트 컨테이너에 갇혀 화면을 꽉 채운다. 시스템이 스스로 present 해야
/// 콘텐츠 양에 맞는 높이로 뜬다(`sheetPresentationController.detents` 지정은 무시된다).
struct TutorialShareSheet: UIViewControllerRepresentable {
    let isPresented: Bool
    /// 시트가 닫힐 때. `completed` 는 사용자가 **우리 익스텐션(꾹)을 골랐는지**다 —
    /// 다른 앱을 골랐거나 시트를 그냥 닫으면 false 다(`isOurShareExtension` 참조).
    let onFinish: (_ completed: Bool) -> Void

    /// 사용자가 **우리 익스텐션**을 골랐는지. `completed` 만 보면 안 된다 —
    /// Copy·메시지·미리 알림 무엇을 골라도 성공하면 true 라, "꾹을 찾아 눌러보게 한다"는
    /// 이 단계의 목적이 무너진다(false 는 시트를 그냥 닫았을 때뿐이다).
    ///
    /// 익스텐션의 activityType 은 그 번들 ID 이고, 익스텐션 번들 ID 는 앱 번들 ID 를 접두사로 갖는다
    /// (`com.mashup.teamMino` / `com.mashup.teamMino.ShareExtension`). 문자열을 박지 않고
    /// 앱 번들 ID 에서 유도해 번들 ID 가 바뀌어도 따라가게 한다.
    ///
    /// 두 타깃의 번들 ID 를 따로 바꿔 이 접두사 관계가 깨지면 꾹을 골라도 false 가 되어
    /// 튜토리얼을 완주할 수 없게 된다(건너뛰기만 남는다) — 번들 ID 를 손볼 때 함께 확인한다.
    private static func isOurShareExtension(_ activityType: UIActivity.ActivityType?) -> Bool {
        // appID 가 없으면(있을 수 없지만) 빈 문자열 접두사로 전부 통과하는 구멍이 생기므로 guard 로 막는다.
        guard let appID = Bundle.main.bundleIdentifier, let activityType else { return false }
        return activityType.rawValue.hasPrefix(appID)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        guard isPresented, host.presentedViewController == nil else { return }
        let controller = UIActivityViewController(
            activityItems: [TutorialShareItem()],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { activityType, completed, _, _ in
            onFinish(completed && Self.isOurShareExtension(activityType))
        }
        // iPad 는 공유시트를 popover 로 띄운다 — popover 는 sourceView·sourceItem·barButtonItem 중
        // 하나를 앵커로 요구하고, 없으면 present 하는 순간 NSGenericException 으로 앱이 죽는다.
        // 이 시트를 연 것은 화면 안의 버튼이 아니라 단계 전이라 가리킬 뷰가 없어,
        // 화살표를 없애고 화면 중앙을 앵커로 잡는다.
        if let popover = controller.popoverPresentationController {
            popover.sourceView = host.view
            popover.sourceRect = CGRect(x: host.view.bounds.midX, y: host.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        host.present(controller, animated: true)
    }
}

/// 공유시트 헤더(제목·썸네일)를 지정하기 위한 아이템.
///
/// `UIActivityItemSource` 를 쓰지 않고 문자열만 넘기면 헤더에 그 문자열이 그대로 노출된다.
private final class TutorialShareItem: NSObject, UIActivityItemSource {
    /// 실제로 공유될 값. **문자열이 아니라 웹 URL 이어야 한다** — 우리 익스텐션의 activation rule 이
    /// `NSExtensionActivationSupportsWebURLWithMaxCount` 라, 문자열을 넘기면 시트에서 "꾹" 이 걸러진다.
    /// 이 센티넬을 받은 익스텐션은 저장 화면을 띄우지 않고 조용히 닫는다(`ShareViewController.classify`).
    private let sharedURL = TutorialShare.sentinelURL

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        sharedURL
    }

    func activityViewController(
        _ controller: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        sharedURL
    }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = "꾹을 찾아 눌러주세요!"
        return metadata
    }
}
