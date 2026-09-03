import SwiftUI
import UIKit

/// 시스템 공유 시트(`UIActivityViewController`) 브릿지.
///
/// SwiftUI 의 `ShareLink` 를 쓰지 않는 이유: `ShareLink` 는 뷰를 만드는 시점에 공유할 값을
/// 요구하는데, 초대 링크는 **탭한 뒤 서버에서 코드를 받아야** 생긴다. 값이 준비되면 코드로
/// 띄워야 하므로 present 를 우리가 제어할 수 있는 이 경로를 쓴다.
///
/// 지금은 이 화면만 쓴다. 두 번째 소비자가 생기면 공용 자리(`*UI` 브릿지 모듈)로 올린다.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    // 링크가 바뀌면 `sheet(item:)` 이 시트를 다시 만든다 — 여기서 갱신할 것이 없다.
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
