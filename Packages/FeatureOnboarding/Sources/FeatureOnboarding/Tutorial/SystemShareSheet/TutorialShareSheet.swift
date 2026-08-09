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
struct TutorialShareSheet: UIViewControllerRepresentable {
    /// 시트가 닫힐 때. `completed` 는 사용자가 공유 대상을 골랐는지(취소가 아닌지)다.
    let onFinish: (_ completed: Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [TutorialShareItem()],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onFinish(completed)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
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
        // 썸네일은 목업이 쓰던 이미지를 그대로 쓴다(디자인 확정 시 교체).
        if let image = UIImage(named: "tutorialSharePreview", in: .module, with: nil) {
            metadata.imageProvider = NSItemProvider(object: image)
        }
        return metadata
    }
}
