import CoreGraphics
import Testing
@testable import ShareExtensionUI

/// 시안 수치는 리뷰에서 눈으로 셀 수 없다 — 값이 바뀌면 여기서 걸린다.
struct SaveLinkSheetMetricsTests {
    /// 시안 기기(홈 인디케이터 34)에서는 시안 값이 그대로 나온다.
    @Test("방 개수별 높이 — 시안 기기", arguments: [
        (roomCount: 0, expected: CGFloat(436)),
        (roomCount: 3, expected: CGFloat(436)),
        (roomCount: 4, expected: CGFloat(612)),
        (roomCount: 5, expected: CGFloat(644)),
        (roomCount: 12, expected: CGFloat(644)),
    ])
    func height_onDesignDevice(roomCount: Int, expected: CGFloat) {
        #expect(SaveLinkSheetMetrics.height(roomCount: roomCount, safeAreaBottom: 34) == expected)
    }

    /// 홈 인디케이터가 없는 기기(SE3)에서는 그만큼 낮아진다 — 화면 667 중 610.
    @Test("하단 safe-area 가 0 이면 34 만큼 낮아진다")
    func height_withoutHomeIndicator() {
        #expect(SaveLinkSheetMetrics.height(roomCount: 5, safeAreaBottom: 0) == CGFloat(610))
        #expect(SaveLinkSheetMetrics.height(roomCount: 3, safeAreaBottom: 0) == CGFloat(402))
    }
}
