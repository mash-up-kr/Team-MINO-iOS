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
    /// 시트가 닫힐 때. `completed` 는 사용자가 공유 대상을 골랐는지(취소가 아닌지)다.
    let onFinish: (_ completed: Bool) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        guard isPresented, host.presentedViewController == nil else { return }
        let controller = UIActivityViewController(
            activityItems: [TutorialShareItem()],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onFinish(completed)
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
    // 실제로 공유될 값. 고른 앱으로 전달되지만 튜토리얼에서는 쓰이지 않는다.
    private let placeholder = "꾹"

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        placeholder
    }

    func activityViewController(
        _ controller: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        placeholder
    }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = "꾹을 찾아 눌러주세요!"
        return metadata
    }
}
