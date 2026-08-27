import XCTest
import UIKit
@testable import DesignSystem

final class MHIllustrationTests: XCTestCase {
    // 에셋을 패키지 사이로 옮길 때(FeatureOnboarding → DesignSystem) 이름이 어긋나면
    // 화면은 빈 이미지만 그리고 조용히 통과한다 — 그걸 잡는 유일한 오라클이다.
    func testAllIllustrationAssetsResolve() {
        for illustration in MHIllustration.allCases {
            XCTAssertNotNil(
                UIImage(named: illustration.rawValue, in: SemanticColorBundle.current, compatibleWith: nil),
                "Missing illustration asset: \(illustration.rawValue)"
            )
        }
    }
}
