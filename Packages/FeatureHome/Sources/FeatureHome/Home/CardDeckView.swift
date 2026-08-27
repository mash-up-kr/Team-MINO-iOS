import DesignSystem
import Domain
import SwiftUI

/// 홈 카드 스와이프 덱. 최대 5장을 겹쳐 표시하고 좌우 스와이프로 넘긴다.
struct CardDeckView: View {
    let pins: [Pin]
    let currentIndex: Int
    /// 첫 카드에서 뒤로 넘겼을 때 이전 덱(기준)으로 돌아갈 수 있는지. false 면 첫 카드가 덱의 끝이다.
    let canReturnToPreviousDeck: Bool
    /// 그때 돌아올 카드 — 이전 덱의 마지막 카드. 아직 그 덱을 받아 두지 않았으면 nil 이고,
    /// 전환은 그대로 일어나되 복귀 애니메이션에 얹을 카드만 없다.
    let previousDeckLastCard: Pin?
    let onSwipeForward: () -> Void
    let onSwipeBackward: () -> Void
    let onTapCard: (PinID) -> Void
    /// 카드 더보기 메뉴 "다른 방 저장" 탭 — 게시물 저장 바텀시트로 이어진다.
    let onSaveToOtherRoom: (PinID) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isFlingAnimating = false
    @State private var flingXOffset: CGFloat = 0
    @State private var flingYOffset: CGFloat = 0
    @State private var flingRotation: Double = 0
    @State private var shiftProgress: CGFloat = 0
    /// 좌스와이프 시 이전 카드 복귀 진행도 (0=우상단, 1=center)
    @State private var returnProgress: CGFloat = 0
    /// 컨테이너 실측 폭(스크린 폭). GeometryReader 로 주입받는다 —
    /// `UIScreen.main.bounds` 는 iOS 16+ deprecated 이고 멀티윈도우/회전/iPad 에서 부정확하다.
    @State private var containerWidth: CGFloat = 0

    private var baseCardWidth: CGFloat { CardDeckLayout.baseCardWidth(containerWidth: containerWidth) }
    private var screenWidth: CGFloat { containerWidth }

    // MARK: - 상수 (뷰 전용 애니메이션 값. 레이아웃·제스처 판정 상수·순수 계산은 CardDeckLayout)

    private enum Anim {
        static let springDuration: TimeInterval = 0.2      // fling·복귀·제자리 스프링
        static let dragMinimum: CGFloat = 10               // DragGesture 최소 인식 거리
        static let backwardDragRange: CGFloat = 200        // 좌드래그 → returnProgress(0…1) 정규화 폭
        static let flingRotation: Double = 20              // 카드가 날아갈 때 회전각(부호는 방향)
        static let dragRotationDivisor: Double = 30        // 드래그 중 회전 = -dragOffset / 이 값
        static let verticalDragFactor: CGFloat = 0.4       // 드래그 시 위로 뜨는 정도 = dragOffset × 이 값
        static let flyUpFactor: CGFloat = 0.4              // 날아갈 때 위로 = screenWidth × 이 값
    }

    var body: some View {
        // 앞 카드를 고정 앵커(offset 0)로 두고 뒤 카드가 위로 겹친다. 앞 카드 위치가 카드 수와 무관하게
        // 고정돼야 넘길 때·재생성할 때 덱 높이가 튀지 않는다. (스택이 얕으면 위쪽이 비는 건 "카드 소진" 표현)
        ZStack(alignment: .center) {
            // 일반 카드 스택
            ForEach(Array(visibleCards.enumerated()), id: \.element.id) { stackIndex, pin in
                let isTop = stackIndex == visibleCards.count - 1
                let depth = visibleCards.count - 1 - stackIndex
                let effectiveDepth = CardDeckLayout.effectiveDepth(depth: depth, isTop: isTop, shiftProgress: shiftProgress, returnProgress: returnProgress)
                let cardWidth = CardDeckLayout.cardWidth(containerWidth: containerWidth, effectiveDepth: effectiveDepth)

                cardView(pin: pin)
                    .frame(width: cardWidth)
                    .offset(y: effectiveDepth * -CardDeckLayout.depthStep)
                    .opacity(CardDeckLayout.interpolatedOpacity(depth: depth, isTop: isTop, shiftProgress: shiftProgress) * CardDeckLayout.depthFade(effectiveDepth))
                    .zIndex(Double(stackIndex))
                    .offset(x: isTop ? dragOffset + flingXOffset : 0, y: isTop ? dragYOffset + flingYOffset : 0)
                    .rotationEffect(isTop ? .degrees(topRotation) : .zero)
                    .allowsHitTesting(isTop && !isFlingAnimating)
                    .gesture(isTop ? swipeGesture : nil)
                    .onTapGesture { onTapCard(pin.id) }
            }

            // 이전 카드 (좌스와이프 시 우상단에서 돌아옴)
            if returnProgress > 0, let prevPin = previousPin {
                cardView(pin: prevPin)
                    .frame(width: baseCardWidth)
                    .offset(
                        x: screenWidth * (1 - returnProgress),
                        y: -screenWidth * Anim.flyUpFactor * (1 - returnProgress)
                    )
                    .rotationEffect(.degrees(-Anim.flingRotation * Double(1 - returnProgress)))
                    .zIndex(Double(CardDeckLayout.visibleCount + 1))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .background(widthReader)   // 컨테이너 실측 폭 주입(UIScreen.main 대체)
    }

    /// 컨테이너 폭을 측정해 `containerWidth` 에 넣는 투명 리더. 레이아웃엔 영향 없다.
    private var widthReader: some View {
        GeometryReader { geo in
            Color.clear.onChange(of: geo.size.width, initial: true) { _, width in
                containerWidth = width
            }
        }
    }

    // MARK: - 카드 데이터

    private var visibleCards: [Pin] {
        // 폭이 측정되기 전(첫 레이아웃 패스)엔 그리지 않아 0-폭 카드 깜빡임을 막는다.
        guard containerWidth > 0 else { return [] }
        return Array(pins[CardDeckLayout.visibleRange(currentIndex: currentIndex, pinCount: pins.count)].reversed())
    }

    /// 좌스와이프 때 우상단에서 돌아오는 카드. 덱 안이면 바로 앞 카드, 첫 카드면 이전 덱의 마지막 카드다.
    private var previousPin: Pin? {
        currentIndex > 0 ? pins[currentIndex - 1] : previousDeckLastCard
    }

    // MARK: - 개별 카드

    private func cardView(pin: Pin) -> some View {
        let badge = badgeInfo(for: pin.category)
        return MHHomeCard(
            avatar: nil,
            badgeText: badge.text,
            badgeColor: badge.color,
            title: pin.place.name,
            address: pin.place.address,
            images: [],
            menuItems: moreMenuItems(for: pin)
        )
    }

    /// 카드 더보기(⋮) 메뉴 — Figma `Menu/Menu`.
    private func moreMenuItems(for pin: Pin) -> [MHMenuItem] {
        [
            MHMenuItem("다른 방 저장") { onSaveToOtherRoom(pin.id) },
        ]
    }

    // MARK: - 드래그 연동

    private var dragYOffset: CGFloat {
        guard dragOffset > 0 else { return 0 }
        return -dragOffset * Anim.verticalDragFactor
    }

    private var topRotation: Double {
        guard dragOffset > 0 else { return flingRotation }
        return -Double(dragOffset) / Anim.dragRotationDivisor + flingRotation
    }

    // MARK: - 스와이프 제스처

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: Anim.dragMinimum)
            .onChanged { value in
                let dx = value.translation.width
                if dx >= 0 {
                    // 우측 드래그 — 현재 카드 따라감
                    dragOffset = dx
                    returnProgress = 0
                } else if CardDeckLayout.allowsBackwardDrag(
                    currentIndex: currentIndex,
                    canReturnToPreviousDeck: canReturnToPreviousDeck
                ) {
                    // 좌측 드래그 — 현재 카드 고정, 이전 카드 등장
                    dragOffset = 0
                    returnProgress = min(1, abs(dx) / Anim.backwardDragRange)
                }
            }
            .onEnded { value in
                // "무엇을 할지" 판정은 순수 함수(CardDeckLayout)로 분리하고, 여기선 그 결과에 애니메이션만 건다.
                switch CardDeckLayout.swipeOutcome(
                    predicted: value.predictedEndTranslation.width,
                    returnProgress: returnProgress,
                    currentIndex: currentIndex,
                    pinCount: pins.count
                ) {
                case .forward:
                    performFlingForward()
                case .backward:
                    completeBackward()
                case .snapBack:
                    // 충분히 밀지 않음 → 제자리로. (마지막 카드도 넘길 수 있다 — 넘기면 덱이 비고 소진 화면)
                    withAnimation(.spring(duration: Anim.springDuration)) {
                        dragOffset = 0
                        returnProgress = 0
                    }
                }
            }
    }

    // MARK: - 우스와이프 (다음 카드)

    private func performFlingForward() {
        isFlingAnimating = true

        // 카드가 날아가는 동안 히트테스트가 꺼져 다음 스와이프가 막힌다(잠금 시간 ≈ 이 애니메이션 길이).
        // 인덱스 전진이 completion 에서 일어나 그 전엔 잠금을 못 푸므로, 빠른 연속 스와이프 누락을 줄이려
        // fling·shift 를 하나의 0.2s 로 합쳐 잠금 창을 최대한 짧게 한다.
        withAnimation(.spring(duration: Anim.springDuration)) {
            flingXOffset = screenWidth
            flingYOffset = -screenWidth * Anim.flyUpFactor
            flingRotation = -Anim.flingRotation
            shiftProgress = 1.0
        } completion: {
            dragOffset = 0
            flingXOffset = 0
            flingYOffset = 0
            flingRotation = 0
            shiftProgress = 0
            isFlingAnimating = false
            onSwipeForward()
        }
    }

    // MARK: - 좌스와이프 (이전 카드)

    private func completeBackward() {
        isFlingAnimating = true

        withAnimation(.spring(duration: Anim.springDuration)) {
            returnProgress = 1
        } completion: {
            // returnProgress=1 시 덱이 이미 1칸 밀린 상태 → 인덱스 변경 후 위치 일치
            var t = Transaction(animation: nil)
            t.disablesAnimations = true
            withTransaction(t) {
                returnProgress = 0
                onSwipeBackward()
            }
            isFlingAnimating = false
        }
    }
}

// MARK: - 카테고리 → 뱃지 매핑 (Feature 레이어 책임)

private func badgeInfo(for category: PinCategory) -> (text: String, color: Color) {
    switch category {
    case .worthVisiting:        return ("가볼 만한 곳", .mhAccentForegroundLime)
    case .popularAmongFriends:  return ("친구들이 많이 본 곳", .mhAccentForegroundLightBlue)
    case .savedByMany:          return ("여럿이 저장한 곳", .mhAccentForegroundRedOrange)
    case .manyStories:          return ("이야기 많은 곳", .mhAccentForegroundPink)
    }
}
