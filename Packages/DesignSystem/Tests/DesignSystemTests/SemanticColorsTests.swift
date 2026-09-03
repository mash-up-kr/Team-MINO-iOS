import XCTest
import UIKit
@testable import DesignSystem

final class SemanticColorsTests: XCTestCase {
    func testAllSemanticColorAssetsResolve() {
        let names: [String] = [
            "Label/Strong",
            "Label/Normal",
            "Label/Neutral",
            "Label/Alternative",
            "Label/Assistive",
            "Label/Disable",
            "Primary/Normal",
            "Primary/Strong",
            "Primary/Heavy",
            "Background/Normal/Normal",
            "Background/Normal/Alternative",
            "Background/Elevated/Normal",
            "Background/Elevated/Alternative",
            "Background/Transparent/Normal",
            "Background/Transparent/Alternative",
            "Interaction/Inactive",
            "Interaction/Disable",
            "Line/Normal/Normal",
            "Line/Normal/Neutral",
            "Line/Normal/Alternative",
            "Line/Solid/Normal",
            "Line/Solid/Neutral",
            "Line/Solid/Alternative",
            "Status/Positive",
            "Status/Cautionary",
            "Status/Negative",
            "Accent/Background/Red Orange",
            "Accent/Background/Lime",
            "Accent/Background/Cyan",
            "Accent/Background/Light Blue",
            "Accent/Background/Violet",
            "Accent/Background/Purple",
            "Accent/Background/Pink",
            "Accent/Foreground/Red",
            "Accent/Foreground/Red Orange",
            "Accent/Foreground/Orange",
            "Accent/Foreground/Lime",
            "Accent/Foreground/Green",
            "Accent/Foreground/Cyan",
            "Accent/Foreground/Light Blue",
            "Accent/Foreground/Blue",
            "Accent/Foreground/Violet",
            "Accent/Foreground/Purple",
            "Accent/Foreground/Pink",
            "Inverse/Primary",
            "Inverse/Background",
            "Inverse/Label",
            "Static/White",
            "Static/Black",
            "Fill/Normal",
            "Fill/Strong",
            "Fill/Alternative",
            "Material/Dimmer",
        ]
        for name in names {
            XCTAssertNotNil(
                UIColor(named: name, in: SemanticColorBundle.current, compatibleWith: nil),
                "Missing semantic color asset: \(name)"
            )
        }
    }
}
