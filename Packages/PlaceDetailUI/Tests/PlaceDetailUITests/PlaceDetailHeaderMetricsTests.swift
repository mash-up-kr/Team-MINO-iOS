import CoreGraphics
import DesignSystem
import Testing
@testable import PlaceDetailUI

/// 시안 수치는 리뷰에서 눈으로 셀 수 없다 — 값이 바뀌면 여기서 걸린다.
struct PlaceDetailHeaderMetricsTests {
    /// 그래버가 붙는 단계(`MHBottomSheet` 는 full 에서만 뺀다)는 그 30pt 프레임이 시안의 30 을
    /// 이미 채운다 — 헤더가 여기에 더 얹으면 그만큼 통째로 초과한다.
    @Test("그래버가 있는 단계는 헤더가 상단 여백을 더하지 않는다",
          arguments: [MHBottomSheetDetent.low, .medium])
    func grabberStagesAddNothing(detent: MHBottomSheetDetent) {
        #expect(PlaceDetailHeaderMetrics.topInset(for: detent) == 0)
    }

    /// full 은 그래버가 없어 헤더가 직접 낸다 — 005-2-1 `Frame 303` 의 닫기 버튼이 y=12.
    @Test("full 은 시안대로 12 를 유지한다")
    func fullKeepsDesignInset() {
        #expect(PlaceDetailHeaderMetrics.topInset(for: .full) == CGFloat(12))
    }
}
