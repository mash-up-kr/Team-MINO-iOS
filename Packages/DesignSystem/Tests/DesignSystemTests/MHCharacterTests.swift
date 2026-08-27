import XCTest
import UIKit
@testable import DesignSystem

final class MHCharacterTests: XCTestCase {
    func testAllCharacterAssetsResolve() {
        for character in MHCharacter.allCases {
            XCTAssertNotNil(
                UIImage(named: character.rawValue, in: SemanticColorBundle.current, compatibleWith: nil),
                "Missing character asset: \(character.rawValue)"
            )
        }
    }

    // Figma `010-1. 프로필 설정` 그리드가 4열 × 3행 = 12종이다.
    // 선택 결과가 Int 인덱스로 저장되므로 개수와 순서가 계약이다.
    func testCharacterCountMatchesFigma() {
        XCTAssertEqual(MHCharacter.allCases.count, 12)
    }
}
