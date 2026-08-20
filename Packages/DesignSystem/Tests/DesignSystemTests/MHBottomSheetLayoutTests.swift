import XCTest
@testable import DesignSystem

final class MHBottomSheetLayoutTests: XCTestCase {
    // 컨테이너 800pt, low 15% / medium 45% → low 120, medium 360, full 800
    private let layout = MHBottomSheetLayout(containerHeight: 800, lowFraction: 0.15, mediumFraction: 0.45)

    func testHeightPerDetent() {
        XCTAssertEqual(layout.height(of: .low), 120)
        XCTAssertEqual(layout.height(of: .medium), 360)
        XCTAssertEqual(layout.height(of: .full), 800)
    }

    func testClampedHeightBounds() {
        XCTAssertEqual(layout.clampedHeight(50), 120, "low 아래로 못 내려간다")
        XCTAssertEqual(layout.clampedHeight(1000), 800, "full 위로 못 올라간다")
        XCTAssertEqual(layout.clampedHeight(500), 500, "범위 안은 그대로")
    }

    func testNearestDetentSnapsToClosest() {
        XCTAssertEqual(layout.nearestDetent(to: 130), .low)
        XCTAssertEqual(layout.nearestDetent(to: 350), .medium)
        XCTAssertEqual(layout.nearestDetent(to: 700), .full)
    }

    func testNearestDetentAtMidpoints() {
        // low(120)~medium(360) 중간 = 240, medium(360)~full(800) 중간 = 580
        XCTAssertEqual(layout.nearestDetent(to: 239), .low)
        XCTAssertEqual(layout.nearestDetent(to: 241), .medium)
        XCTAssertEqual(layout.nearestDetent(to: 579), .medium)
        XCTAssertEqual(layout.nearestDetent(to: 581), .full)
    }

    func testNearestDetentOutOfBounds() {
        XCTAssertEqual(layout.nearestDetent(to: -100), .low, "범위 밖 아래는 low")
        XCTAssertEqual(layout.nearestDetent(to: 2000), .full, "범위 밖 위는 full")
    }

    private let twoStep = MHBottomSheetLayout(
        containerHeight: 800, lowFraction: 0.15, mediumFraction: 0.45, detents: [.medium, .full]
    )

    func testNearestDetentSkipsExcludedDetent() {
        XCTAssertEqual(twoStep.nearestDetent(to: 130), .medium, "low 는 후보에서 빠져 medium 으로 붙는다")
        XCTAssertEqual(twoStep.nearestDetent(to: 579), .medium)
        XCTAssertEqual(twoStep.nearestDetent(to: 581), .full)
    }

    func testClampedHeightUsesLowestUsableDetent() {
        XCTAssertEqual(twoStep.clampedHeight(50), 360, "medium 아래로 못 내려간다")
        XCTAssertEqual(twoStep.clampedHeight(1000), 800)
        XCTAssertEqual(twoStep.clampedHeight(500), 500)
    }
}
