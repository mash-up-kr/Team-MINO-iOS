import CoreGraphics

/// 카드 덱의 순수 레이아웃·제스처 계산.
///
/// `CardDeckView` 의 뷰 로직(@State·SwiftUI 애니메이션·completion 핸들러)에서 **"무엇을 할지"·"어떻게 보일지"를
/// 정하는 순수 함수만** 떼어낸 자리다. 뷰는 단위테스트하지 않는다는 전략은 유지하되, 덱에서 가장 복잡한
/// 스와이프 판정·겹침 계산은 여기서 결정적으로 검증한다(뷰는 이 결과에 애니메이션만 입힌다).
enum CardDeckLayout {
    /// 한 번에 겹쳐 보이는 카드 수(앞 카드 포함).
    static let visibleCount = 5
    /// 뒤 카드 1단계당 폭 축소·y 이동량.
    static let depthStep: CGFloat = 20
    /// 카드 좌우 여백(20 × 2).
    static let cardHorizontalInset: CGFloat = 40

    // 스택 깊이별 불투명도(index 0 = 맨 앞).
    private static let opacityValues: [Double] = [1.0, 0.98, 0.90, 0.80, 0.70]

    // MARK: - 제스처 판정 임계 (predictedEnd 기반)

    /// 우측으로 이만큼 이상 던지면 다음 카드로 넘긴다.
    static let forwardFlingThreshold: CGFloat = 100
    /// 좌측으로 이만큼 이상 던지면(부호 반대) 이전 카드로 복귀한다.
    static let backwardFlingThreshold: CGFloat = 100
    /// 좌드래그 복귀 진행도가 이 값을 넘으면 이전 카드로 확정한다.
    static let backwardProgressThreshold: CGFloat = 0.3

    /// 스와이프를 인식하지 않는 **좌측 가장자리** 폭(pt).
    ///
    /// 정책(카드덱 FR-003): 화면 좌측 영역에서 시작한 드래그는 카드 전환·복구에 반영하지 않는다.
    /// 그 "영역" 의 경계를 시안·PRD 가 pt 로 못 박지 않아 처음에는 화면을 반으로 갈랐는데
    /// (spec research.md R-005 가 "가정 — 디자이너 확인 항목" 으로 남겨 둔 값), 카드가 컨테이너
    /// 가운데 정렬이라 그 경계가 **카드의 수평 중심**과 겹쳤다. 그래서 카드 왼쪽 절반이 통째로
    /// 사각지대가 됐다 — 사진 타일 2개가 중심을 기준으로 갈라져 있어 왼쪽 타일은 전부 죽고
    /// 오른쪽 타일만 살았다. 같은 자리에서 탭(상세 열기)은 되는데 스와이프만 안 되니
    /// 사용자에겐 규칙이 아니라 고장으로 읽힌다.
    ///
    /// 그래서 제외 범위를 **화면 가장자리**로만 좁힌다. 시스템 엣지 제스처가 차지하는 폭(iOS 약 20pt)에
    /// 여유를 둔 값이다. 덱 컨테이너가 화면 폭 전체라(좌우 패딩 없음) 이 값이 곧 화면 왼쪽 끝에서의
    /// 거리다. 디자이너가 경계를 확정하면 여기만 고친다.
    static let swipeAreaLeadingInset: CGFloat = 24

    /// 이 드래그를 카드 전환·복구에 반영할지. 판정 기준은 **손가락이 닿은 지점**(startLocation)이라,
    /// 우측에서 시작해 좌측까지 끌고 가는 되돌리기 드래그는 끝까지 인식된다.
    ///
    /// `containerWidth` 는 폭을 아직 못 잰 첫 레이아웃 패스를 걸러내는 데만 쓴다 — 그때는 좌표계도
    /// 확정 전이라 startX 를 믿을 수 없다.
    static func recognizesSwipe(startX: CGFloat, containerWidth: CGFloat) -> Bool {
        guard containerWidth > 0 else { return false }
        return startX >= swipeAreaLeadingInset
    }

    /// 드래그가 끝났을 때(onEnded) 덱이 취할 동작.
    enum SwipeOutcome: Equatable {
        case forward    // 다음 카드로 넘김
        case backward   // 이전 카드로 복귀
        case snapBack   // 제자리(넘길 카드 없거나 약하게 밀었을 때)
    }

    /// 좌드래그(뒤로)를 받을지. 되돌리기는 **현재 덱 안에서 1단계**뿐이라 첫 카드에서는 받지 않는다
    /// (EC-001·EC-003 — 덱이 바뀌면 되돌리기 이력이 초기화된다).
    static func allowsBackwardDrag(currentIndex: Int) -> Bool {
        currentIndex > 0
    }

    /// onEnded 분기의 순수 결정. 애니메이션 실행은 뷰가, "무엇을 할지"는 여기가 정한다.
    /// - Parameters:
    ///   - predicted: `predictedEndTranslation.width`(관성 포함 예측 이동량). 우측 +, 좌측 −.
    ///   - returnProgress: 좌드래그로 이전 카드가 돌아온 진행도(0…1).
    ///   - currentIndex: 현재 맨 앞 카드 인덱스.
    ///   - pinCount: 덱 전체 카드 수.
    static func swipeOutcome(
        predicted: CGFloat,
        returnProgress: CGFloat,
        currentIndex: Int,
        pinCount: Int
    ) -> SwipeOutcome {
        if returnProgress > 0 {
            let committed = predicted < -backwardFlingThreshold || returnProgress > backwardProgressThreshold
            return committed ? .backward : .snapBack
        }
        if predicted > forwardFlingThreshold, currentIndex < pinCount {
            return .forward
        }
        // 충분히 밀지 않음 → 제자리. 마지막 카드도 한 번 더 넘길 수 있고(덱 밖으로 나가 소진 화면, 002-3),
        // 이미 덱 밖이면(currentIndex == pinCount) 넘길 카드가 없어 여기로 온다.
        return .snapBack
    }

    // MARK: - 렌더 슬라이스

    /// 현재 인덱스에서 렌더할 카드 범위 [start, end). visibleCount+1 장(+1 은 페이드인 예비 카드)을 감싸되
    /// 덱 경계를 넘지 않는다. 인덱스가 덱을 벗어나면 빈 범위(슬라이싱해도 안전).
    static func visibleRange(currentIndex: Int, pinCount: Int) -> Range<Int> {
        let start = max(0, min(currentIndex, pinCount))
        let end = min(start + visibleCount + 1, pinCount)
        return start..<end
    }

    // MARK: - 겹침 기하

    /// 카드 기준 폭(컨테이너 폭 − 좌우 인셋). 음수는 0 으로 clamp.
    static func baseCardWidth(containerWidth: CGFloat) -> CGFloat {
        max(0, containerWidth - cardHorizontalInset)
    }

    /// 유효 깊이가 반영된 실제 카드 폭.
    static func cardWidth(containerWidth: CGFloat, effectiveDepth: CGFloat) -> CGFloat {
        baseCardWidth(containerWidth: containerWidth) - effectiveDepth * depthStep
    }

    /// 유효 깊이의 카드 축소 배율(앞 카드 = 1).
    ///
    /// 시안의 뒤 카드는 **비율 그대로 줄인 사본**이다 — 폭 315 일 때 높이 308.42(= 328 × 315/335)에
    /// 패딩·테두리까지 같은 배율(16→15.045, 1→0.94)로 줄어 있다(Figma 2809-143391…143395).
    /// 그래서 폭만 좁히면 안 된다: 카드 높이는 내용(이미지 그리드·2줄 텍스트)이 정하므로 폭에 비례해
    /// 줄지 않고, 그만큼 뒤 카드가 아래로 내려앉아 겹침 간격이 시안(20)보다 좁아진다.
    static func cardScale(containerWidth: CGFloat, effectiveDepth: CGFloat) -> CGFloat {
        let base = baseCardWidth(containerWidth: containerWidth)
        guard base > 0 else { return 1 }
        return max(0, cardWidth(containerWidth: containerWidth, effectiveDepth: effectiveDepth) / base)
    }

    /// 스택 내 카드의 유효 깊이(넘김·복귀 진행 반영).
    /// 앞 카드(isTop)는 복귀 진행만큼 뒤로 밀리고, 뒤 카드는 넘김 진행만큼 앞으로 당겨진다.
    static func effectiveDepth(
        depth: Int,
        isTop: Bool,
        shiftProgress: CGFloat,
        returnProgress: CGFloat
    ) -> CGFloat {
        isTop
            ? CGFloat(depth) + returnProgress
            : max(0, CGFloat(depth) - shiftProgress + returnProgress)
    }

    /// 깊이별 불투명도(넘김 진행 중이면 한 단계 앞 값으로 보간). 앞 카드는 항상 불투명(1).
    static func interpolatedOpacity(depth: Int, isTop: Bool, shiftProgress: CGFloat) -> Double {
        guard !isTop else { return opacityValues[0] }
        let from = opacityValues[min(depth, opacityValues.count - 1)]
        let targetDepth = max(0, depth - 1)
        let to = opacityValues[min(targetDepth, opacityValues.count - 1)]
        return from + (to - from) * Double(shiftProgress)
    }

    /// 최대 visible 깊이를 넘어가는 카드는 페이드 아웃(1 → 0).
    static func depthFade(_ effectiveDepth: CGFloat) -> Double {
        let maxDepth = CGFloat(visibleCount - 1)
        guard effectiveDepth > maxDepth else { return 1 }
        return max(0, Double(1 - (effectiveDepth - maxDepth)))
    }
}
