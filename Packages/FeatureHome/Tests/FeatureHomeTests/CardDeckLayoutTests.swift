import CoreGraphics
import Testing
@testable import FeatureHome

/// `CardDeckView` 에서 분리한 순수 레이아웃·제스처 계산 단위테스트.
/// 뷰(@State·애니메이션)는 테스트하지 않지만, 덱에서 가장 복잡한 "무엇을 할지"·"어떻게 보일지" 판정은
/// 여기서 결정적으로 검증한다(제스처 상태기계 사각지대 축소).
struct CardDeckLayoutTests {
    private typealias Layout = CardDeckLayout

    // MARK: - recognizesSwipe (스와이프 인식 영역, FR-003)

    @Test("우측 영역에서 시작한 드래그는 인식한다")
    func recognizes_rightArea() {
        #expect(Layout.recognizesSwipe(startX: 300, containerWidth: 375))
    }

    @Test("좌측 영역에서 시작한 드래그는 카드 전환·복구에 반영하지 않는다 (TS-003)")
    func ignores_leftArea() {
        #expect(!Layout.recognizesSwipe(startX: 40, containerWidth: 375))
    }

    @Test("경계(폭의 절반)는 우측 영역에 포함한다")
    func recognizes_atBoundary() {
        #expect(Layout.recognizesSwipe(startX: 187.5, containerWidth: 375))
        #expect(!Layout.recognizesSwipe(startX: 187.49, containerWidth: 375))
    }

    @Test("폭을 아직 못 재면(첫 레이아웃 패스) 인식하지 않는다 — 0 나눗셈·오판정 방지")
    func ignores_beforeMeasured() {
        #expect(!Layout.recognizesSwipe(startX: 100, containerWidth: 0))
    }

    // MARK: - swipeOutcome (onEnded 분기)

    @Test("우측으로 충분히 던지면(예측 > 임계) 다음 카드로 forward")
    func swipe_forward_whenFlungRight() {
        #expect(Layout.swipeOutcome(predicted: 150, returnProgress: 0, currentIndex: 0, pinCount: 5) == .forward)
    }

    @Test("마지막 카드에서도 우측으로 던지면 forward — 덱 밖으로 나가 소진 화면이 된다(002-3)")
    func swipe_forward_atLastCard() {
        #expect(Layout.swipeOutcome(predicted: 300, returnProgress: 0, currentIndex: 4, pinCount: 5) == .forward)
    }

    @Test("이미 덱 밖(소진)이면 우측으로 던져도 snapBack (넘길 카드 없음)")
    func swipe_snapBack_pastDeck() {
        #expect(Layout.swipeOutcome(predicted: 300, returnProgress: 0, currentIndex: 5, pinCount: 5) == .snapBack)
    }

    @Test("우측으로 살짝만 밀면(예측 ≤ 임계) 제자리 snapBack")
    func swipe_snapBack_whenWeakRight() {
        #expect(Layout.swipeOutcome(predicted: 40, returnProgress: 0, currentIndex: 0, pinCount: 5) == .snapBack)
    }

    @Test("좌드래그 복귀 진행도가 임계를 넘으면 이전 카드로 backward")
    func swipe_backward_whenProgressPastThreshold() {
        #expect(Layout.swipeOutcome(predicted: 0, returnProgress: 0.5, currentIndex: 2, pinCount: 5) == .backward)
    }

    @Test("좌드래그가 약하면(진행도·예측 모두 미달) snapBack")
    func swipe_snapBack_whenWeakLeft() {
        #expect(Layout.swipeOutcome(predicted: -10, returnProgress: 0.1, currentIndex: 2, pinCount: 5) == .snapBack)
    }

    @Test("좌드래그 진행도는 낮아도 좌측 예측이 임계를 넘으면 backward (빠른 플릭)")
    func swipe_backward_whenFlickedLeft() {
        #expect(Layout.swipeOutcome(predicted: -150, returnProgress: 0.1, currentIndex: 2, pinCount: 5) == .backward)
    }

    // MARK: - allowsBackwardDrag (좌드래그 수용 여부)

    @Test("덱 안에서는 좌드래그를 받는다")
    func allowsBackwardDrag_insideDeck() {
        #expect(Layout.allowsBackwardDrag(currentIndex: 2))
    }

    @Test("첫 카드에서는 좌드래그를 받지 않는다 — 되돌리기가 덱 경계를 넘지 않는다 (EC-001·EC-003)")
    func allowsBackwardDrag_atFirstCard() {
        #expect(Layout.allowsBackwardDrag(currentIndex: 0) == false)
    }

    // MARK: - visibleRange (렌더 슬라이스)

    @Test("visibleRange 는 현재 인덱스부터 최대 visibleCount+1 장을 감싼다")
    func visibleRange_capsAtRenderCount() {
        #expect(Layout.visibleRange(currentIndex: 0, pinCount: 100) == 0..<(Layout.visibleCount + 1))
    }

    @Test("visibleRange 는 덱 끝을 넘지 않는다")
    func visibleRange_clampsToEnd() {
        #expect(Layout.visibleRange(currentIndex: 8, pinCount: 10) == 8..<10)
    }

    @Test("visibleRange 는 인덱스가 덱을 벗어나면 빈 범위(슬라이싱해도 안전)")
    func visibleRange_emptyWhenOutOfBounds() {
        let range = Layout.visibleRange(currentIndex: 12, pinCount: 10)
        #expect(range.isEmpty)
        #expect(range.lowerBound <= 10)   // 상한 이내라 pins[range] 가 크래시하지 않는다
    }

    // MARK: - depthFade / effectiveDepth / opacity

    @Test("depthFade 는 최대 깊이 이내면 1, 넘으면 0 으로 페이드")
    func depthFade_fadesBeyondMaxDepth() {
        #expect(Layout.depthFade(0) == 1)
        #expect(Layout.depthFade(CGFloat(Layout.visibleCount - 1)) == 1)   // 경계(4)는 아직 1
        #expect(Layout.depthFade(CGFloat(Layout.visibleCount)) == 0)       // 한 단계 더(5) 넘으면 0
        #expect(Layout.depthFade(CGFloat(Layout.visibleCount - 1) + 0.5) == 0.5)
    }

    @Test("effectiveDepth — 진행 없으면 depth 그대로, 넘김은 뒤카드를 당기고 복귀는 앞카드를 민다")
    func effectiveDepth_reflectsProgress() {
        #expect(Layout.effectiveDepth(depth: 2, isTop: false, shiftProgress: 0, returnProgress: 0) == 2)
        #expect(Layout.effectiveDepth(depth: 2, isTop: false, shiftProgress: 1, returnProgress: 0) == 1)   // 넘김 진행만큼 당겨짐
        #expect(Layout.effectiveDepth(depth: 0, isTop: true, shiftProgress: 0, returnProgress: 1) == 1)    // 앞카드는 복귀만큼 밀림
    }

    @Test("interpolatedOpacity — 앞카드는 항상 1, 뒤카드는 넘김 진행에 따라 한 단계 앞으로 단조 증가")
    func interpolatedOpacity_interpolatesMonotonically() {
        #expect(Layout.interpolatedOpacity(depth: 0, isTop: true, shiftProgress: 0.5) == 1.0)
        let at0 = Layout.interpolatedOpacity(depth: 2, isTop: false, shiftProgress: 0)
        let at1 = Layout.interpolatedOpacity(depth: 2, isTop: false, shiftProgress: 1)
        let mid = Layout.interpolatedOpacity(depth: 2, isTop: false, shiftProgress: 0.5)
        #expect(at1 > at0)            // 앞으로 당겨질수록 불투명
        #expect(mid > at0 && mid < at1)
    }

    @Test("baseCardWidth 는 컨테이너 폭에서 좌우 인셋을 뺀 값, 인셋보다 좁으면 0 으로 clamp")
    func baseCardWidth_clampsNonNegative() {
        #expect(Layout.baseCardWidth(containerWidth: 375) == 375 - Layout.cardHorizontalInset)
        #expect(Layout.baseCardWidth(containerWidth: 10) == 0)
    }

    @Test("cardScale 은 시안 덱의 폭·높이를 그대로 재현한다 (뒤 카드 = 비율 축소 사본)")
    func cardScale_matchesFigmaDeck() {
        // Figma 002-5-1 덱(2809-143391…143395): 폭 255·275·295·315·335 / 높이 249.67·269.25·288.84·308.42·328
        let widths: [CGFloat] = [335, 315, 295, 275, 255]
        let heights: [CGFloat] = [328, 308.418, 288.836, 269.254, 249.672]
        for depth in 0..<5 {
            let scale = Layout.cardScale(containerWidth: 375, effectiveDepth: CGFloat(depth))
            #expect(abs(scale * 335 - widths[depth]) < 0.001)
            #expect(abs(scale * 328 - heights[depth]) < 0.01)
        }
    }

    @Test("컨테이너 폭이 인셋보다 좁으면 cardScale 은 1 로 떨어진다(0 나눗셈 방어)")
    func cardScale_guardsZeroBase() {
        #expect(Layout.cardScale(containerWidth: 10, effectiveDepth: 1) == 1)
    }
}
