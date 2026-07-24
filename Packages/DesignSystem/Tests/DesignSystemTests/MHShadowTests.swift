import XCTest
import UIKit
@testable import DesignSystem

final class MHShadowTests: XCTestCase {
    func testLayerCountsMatchFigma() {
        XCTAssertEqual(MHShadow.xsmall.layers.count, 1)
        XCTAssertEqual(MHShadow.small.layers.count, 2)
        XCTAssertEqual(MHShadow.medium.layers.count, 2)
        XCTAssertEqual(MHShadow.large.layers.count, 2)
        XCTAssertEqual(MHShadow.xlarge.layers.count, 2)
    }

    func testEveryTokenHasLayers() {
        for shadow in MHShadow.allCases {
            XCTAssertFalse(shadow.layers.isEmpty, "\(shadow) has no layers")
        }
    }

    func testSpreadShadowSpecs() {
        XCTAssertEqual(MHSpreadShadow.small.spec.blur, 60)
        XCTAssertEqual(MHSpreadShadow.medium.spec.blur, 75)
        XCTAssertEqual(MHSpreadShadow.medium.spec.y, 15)
    }

    // CALayer가 Figma layer 값(blur/2·offset·spread path)대로 설정되는지 런타임 검증.
    @MainActor
    func testCALayerConfiguredFromFigmaValues() {
        let view = MHShadowUIView()
        view.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
        view.cornerRadius = 12
        view.layerSpecs = MHShadow.large.layers
        view.layoutIfNeeded()

        let casters = view.layer.sublayers ?? []
        XCTAssertEqual(casters.count, MHShadow.large.layers.count)
        for (caster, spec) in zip(casters, MHShadow.large.layers) {
            XCTAssertEqual(caster.shadowRadius, spec.blur / 2, accuracy: 0.001)
            XCTAssertEqual(caster.shadowOffset, CGSize(width: spec.x, height: spec.y))
            XCTAssertEqual(caster.shadowOpacity, 1)
            XCTAssertNotNil(caster.shadowPath, "shadowPath(=spread 반영)가 설정돼야 한다")
        }
    }
}
