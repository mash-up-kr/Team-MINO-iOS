import XCTest
import UIKit
@testable import DesignSystem

final class MHIconTests: XCTestCase {
    func testAllIconAssetsResolve() {
        for icon in MHIcon.allCases {
            XCTAssertNotNil(
                UIImage(named: icon.rawValue, in: SemanticColorBundle.current, compatibleWith: nil),
                "Missing icon asset: \(icon.rawValue)"
            )
        }
    }

    // Figma `Icon/Normal/*` 세트 개수(변형 포함)와 일치.
    // 114(초기 세트) + circleClose(Textfield clear 버튼용, Icon/Normal/Circle Close) = 115.
    func testIconCountMatchesFigma() {
        XCTAssertEqual(MHIcon.allCases.count, 115)
    }
}
