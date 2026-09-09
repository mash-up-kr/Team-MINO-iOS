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

    // MARK: - peek → fraction

    /// 덮는 크롬이 없으면 peek 이 그대로 노출 높이가 된다.
    func testFractionWithoutCoverageExposesPeek() {
        let fraction = MHBottomSheetLayout.fraction(
            peek: 88, bottomCoverage: 0, containerHeight: 800, minimum: 0.05, maximum: 0.99
        )
        XCTAssertEqual(800 * fraction, 88, accuracy: 0.001)
    }

    /// 탭바가 덮는 만큼을 더해야 peek 이 **탭바 위로** 노출된다.
    /// 402×874 기기 실측: 컨테이너 778, 탭바 52 → 시트 140 이라야 탭바 위 88 이 보인다.
    func testFractionAddsBottomCoverage() {
        let fraction = MHBottomSheetLayout.fraction(
            peek: 88, bottomCoverage: 52, containerHeight: 778, minimum: 0.05, maximum: 0.99
        )
        XCTAssertEqual(778 * fraction, 140, accuracy: 0.001)
    }

    /// 하단 safe-area 는 섞이지 않는다 — 기기 인셋이 달라도 노출 높이는 같다.
    func testFractionIsIndependentOfContainerHeight() {
        let tall = MHBottomSheetLayout.fraction(
            peek: 256, bottomCoverage: 52, containerHeight: 778, minimum: 0.1, maximum: 0.99
        )
        let short = MHBottomSheetLayout.fraction(
            peek: 256, bottomCoverage: 52, containerHeight: 600, minimum: 0.1, maximum: 0.99
        )
        XCTAssertEqual(778 * tall, 308, accuracy: 0.001)
        XCTAssertEqual(600 * short, 308, accuracy: 0.001)
    }

    func testFractionClampsToMaximum() {
        let fraction = MHBottomSheetLayout.fraction(
            peek: 900, bottomCoverage: 52, containerHeight: 800, minimum: 0.1, maximum: 0.99
        )
        XCTAssertEqual(fraction, 0.99, accuracy: 0.0001)
    }

    /// 상한이 하한보다 낮은 비정상 입력에서는 하한이 이긴다(low 상한 = medium − 0.01).
    func testFractionLowerBoundWinsOverInvertedRange() {
        let fraction = MHBottomSheetLayout.fraction(
            peek: 1, bottomCoverage: 0, containerHeight: 800, minimum: 0.05, maximum: 0.02
        )
        XCTAssertEqual(fraction, 0.05, accuracy: 0.0001)
    }

    func testFractionFallsBackWhenContainerIsEmpty() {
        let fraction = MHBottomSheetLayout.fraction(
            peek: 88, bottomCoverage: 52, containerHeight: 0, minimum: 0.05, maximum: 0.99
        )
        XCTAssertEqual(fraction, 0.05, accuracy: 0.0001)
    }

    // MARK: - 콘텐츠 상자 하단 확장

    func testContentBottomExtensionCoversHomeIndicatorAtEveryDetent() {
        // full 의 높이도 safe area 안 컨테이너 높이라 full 에서만 빼면 리스트 바닥에 흰 띠가 남는다.
        XCTAssertEqual(
            MHBottomSheetLayout.contentBottomExtension(extendsBelowSafeArea: true, safeAreaBottom: 34), 34
        )
    }

    func testContentBottomExtensionIsZeroWhenDisabled() {
        XCTAssertEqual(
            MHBottomSheetLayout.contentBottomExtension(extendsBelowSafeArea: false, safeAreaBottom: 34), 0
        )
    }

    func testContentBottomExtensionIgnoresNegativeInset() {
        XCTAssertEqual(
            MHBottomSheetLayout.contentBottomExtension(extendsBelowSafeArea: true, safeAreaBottom: -1), 0
        )
    }

    // MARK: - isSheetDrag (축 판정)

    /// 회귀 방지 — 축을 가리지 않던 시절, 시트 안 가로 캐러셀을 넘기면 그 세로 성분까지
    /// 시트가 먹어 시트가 따라 움직였다(장소 상세 사진 캐러셀에서 재현).
    func testHorizontalDragIsNotSheetDrag() {
        // 실제 재현 값: dx -230 / dy +32
        XCTAssertFalse(MHBottomSheetLayout.isSheetDrag(dx: -230, dy: 32))
        XCTAssertFalse(MHBottomSheetLayout.isSheetDrag(dx: 120, dy: -10))
    }

    func testVerticalDragIsSheetDrag() {
        XCTAssertTrue(MHBottomSheetLayout.isSheetDrag(dx: 0, dy: 12))
        XCTAssertTrue(MHBottomSheetLayout.isSheetDrag(dx: -8, dy: -40))
    }

    /// 대각선(동률)은 콘텐츠에 양보한다 — 애매할 때 시트가 움직이는 쪽이 더 거슬린다.
    func testDiagonalTieGoesToContent() {
        XCTAssertFalse(MHBottomSheetLayout.isSheetDrag(dx: 20, dy: 20))
        XCTAssertFalse(MHBottomSheetLayout.isSheetDrag(dx: -20, dy: 20))
    }
}
