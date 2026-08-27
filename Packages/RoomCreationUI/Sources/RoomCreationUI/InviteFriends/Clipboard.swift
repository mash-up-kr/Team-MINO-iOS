import Foundation
import UIKit

/// 시스템 클립보드에 쓰는 얇은 창구.
///
/// 프로토콜이 아니라 클로저를 든 struct 다 — 구현이 한 줄이라 프로토콜·구현체 두 타입이 과하다.
/// 주입받는 이유는 테스트 때문이다: 기본값을 쓰면 reducer 테스트가 **기기의 실제 붙여넣기 보드**를
/// 덮어쓴다(시뮬레이터를 공유하는 다른 테스트에도 남는다).
public struct Clipboard: Sendable {
    private let write: @MainActor @Sendable (URL) -> Void

    public init(write: @escaping @MainActor @Sendable (URL) -> Void) {
        self.write = write
    }

    @MainActor
    public func copy(_ url: URL) {
        write(url)
    }

    /// `url` 이 아니라 **문자열**로 넣는다. URL 타입으로만 넣으면 텍스트만 받는 입력창
    /// (메신저 입력 필드 등)에 붙여넣기가 비어 보인다 — 초대 링크는 거기로 가는 값이다.
    public static let system = Clipboard { UIPasteboard.general.string = $0.absoluteString }
}
