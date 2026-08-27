import SwiftUI
import UIKit

public extension Image {
    /// 번들에 **실제로 존재할 때만** `Image` 를 돌려준다.
    ///
    /// SwiftUI 의 `Image(_:bundle:)` 은 없는 이름을 받아도 실패를 알리지 않고 빈 이미지를 만든다.
    /// 그 값을 `.frame(width:height:)` 로 감싸면 화면에 그 크기만 한 **빈 칸**이 남아, 에셋이
    /// 도착하기 전 화면이 깨진 것처럼 보인다. 존재 여부를 먼저 확인해 호출부가 "일러스트 없이
    /// 그리는 모양" 을 고를 수 있게 한다.
    static func mhAssetIfAvailable(_ name: String, bundle: Bundle) -> Image? {
        UIImage(named: name, in: bundle, with: nil).map(Image.init(uiImage:))
    }
}
