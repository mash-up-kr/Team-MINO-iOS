import XCTest
import UIKit
@testable import DesignSystem

final class CharacterArtTests: XCTestCase {
    func testAllRoomCoverAssetsResolve() {
        for cover in MHRoomCover.allCases {
            XCTAssertNotNil(
                UIImage(named: cover.rawValue, in: SemanticColorBundle.current, compatibleWith: nil),
                "Missing room cover asset: \(cover.rawValue)"
            )
        }
    }

    func testAllAvatarProfileAssetsResolve() {
        for avatar in MHAvatarProfile.allCases {
            XCTAssertNotNil(
                UIImage(named: avatar.rawValue, in: SemanticColorBundle.current, compatibleWith: nil),
                "Missing avatar profile asset: \(avatar.rawValue)"
            )
        }
    }

    // Figma `character` 섹션의 세 아트 세트는 팔레트 축이 같다 — black + 12색.
    // 하나만 색이 빠지면 그 색 계정에서 그 자리만 비므로 개수를 함께 고정한다.
    func testArtSetsShareThePaletteAxis() {
        XCTAssertEqual(MHRoomCover.allCases.count, 13)
        XCTAssertEqual(MHAvatarProfile.allCases.count, 13)
        XCTAssertEqual(MHHomeMascot.allCases.count, 13)
    }
}
