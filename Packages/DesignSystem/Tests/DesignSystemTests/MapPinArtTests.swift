import XCTest
import UIKit
@testable import DesignSystem

final class MapPinArtTests: XCTestCase {
    // 에셋 이름을 접두사+접미사로 조립하므로, 조합 하나라도 어긋나면 그 색·상태만 조용히 빈다.
    // 26조합을 전부 짚는다.
    func testEveryColorStateCombinationResolves() {
        for state in MHMapPinState.allCases {
            for color in MHMapPinColor.allCases {
                let name = state.rawValue + color.rawValue
                XCTAssertNotNil(
                    UIImage(named: name, in: SemanticColorBundle.current, compatibleWith: nil),
                    "Missing map pin asset: \(name)"
                )
            }
        }
    }

    func testPaletteAxisMatchesTheOtherArtSets() {
        XCTAssertEqual(MHMapPinColor.allCases.count, 13)
        XCTAssertEqual(MHMapPinColor.allCases.count, MHHomeMascot.allCases.count)
    }
}
