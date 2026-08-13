import DesignSystem
import Domain
import SwiftUI

/// 홈 카드 스와이프 덱. 최대 5장을 겹쳐 표시하고 좌우 스와이프로 넘긴다.
struct CardDeckView: View {
    let pins: [Pin]
    let currentIndex: Int
    let onSwipeForward: () -> Void
    let onSwipeBackward: () -> Void
    let onTapCard: (PinID) -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isFlingAnimating = false
    @State private var flingXOffset: CGFloat = 0
    @State private var flingYOffset: CGFloat = 0
    @State private var flingRotation: Double = 0
    @State private var shiftProgress: CGFloat = 0
    /// 좌스와이프 시 이전 카드 복귀 진행도 (0=우상단, 1=center)
    @State private var returnProgress: CGFloat = 0

    private let visibleCount = 5
    private var baseCardWidth: CGFloat {
        UIScreen.main.bounds.width - 40
    }
    private var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }

    var body: some View {
        // 앞 카드를 고정 앵커(offset 0)로 두고 뒤 카드가 위로 겹친다. 앞 카드 위치가 카드 수와 무관하게
        // 고정돼야 넘길 때·재생성할 때 덱 높이가 튀지 않는다. (스택이 얕으면 위쪽이 비는 건 "카드 소진" 표현)
        ZStack(alignment: .center) {
            // 일반 카드 스택
            ForEach(Array(visibleCards.enumerated()), id: \.element.id) { stackIndex, pin in
                let isTop = stackIndex == visibleCards.count - 1
                let depth = visibleCards.count - 1 - stackIndex
                let effectiveDepth = isTop ? CGFloat(depth) + returnProgress : max(0, CGFloat(depth) - shiftProgress + returnProgress)
                let cardWidth = baseCardWidth - effectiveDepth * 20

                cardView(pin: pin)
                    .frame(width: cardWidth)
                    .offset(y: effectiveDepth * -20)
                    .opacity(interpolatedOpacity(for: depth, isTop: isTop) * depthFade(effectiveDepth))
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
                        y: -screenWidth * 0.4 * (1 - returnProgress)
                    )
                    .rotationEffect(.degrees(-20 * Double(1 - returnProgress)))
                    .zIndex(Double(visibleCount + 1))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 카드 데이터

    private var visibleCards: [Pin] {
        // +1장 추가로 렌더 → depthFade로 투명 상태에서 시작, 앞으로 당겨지면 페이드인
        let renderCount = visibleCount + 1
        let end = min(currentIndex + renderCount, pins.count)
        guard currentIndex < end else { return [] }
        return Array(pins[currentIndex..<end].reversed())
    }

    private var previousPin: Pin? {
        guard currentIndex > 0 else { return nil }
        return pins[currentIndex - 1]
    }

    // MARK: - 개별 카드

    private func cardView(pin: Pin) -> some View {
        let badge = badgeInfo(for: pin.category)
        return MHHomeCard(
            avatar: nil,
            badgeText: badge.text,
            badgeColor: badge.color,
            title: pin.title,
            address: pin.address,
            images: [],
            menuItems: moreMenuItems(for: pin)
        )
    }

    /// 카드 더보기(⋮) 메뉴 — Figma `Menu/Menu`. 항목 동작은 후속 작업이라 지금은 자리(TODO)만 잡는다.
    private func moreMenuItems(for pin: Pin) -> [MHMenuItem] {
        [
            MHMenuItem("다른 방 저장") {
                // TODO: 다른 방에 저장 — 002-4-1 방 변경 바텀시트로 저장 진행
            },
            MHMenuItem("장소 가리기") {
                // TODO: 장소 가리기 — 이 장소를 덱에서 숨김
            },
        ]
    }

    // MARK: - 스택 시각 효과

    private static let opacityValues: [Double] = [1.0, 0.98, 0.90, 0.80, 0.70]

    private func interpolatedOpacity(for depth: Int, isTop: Bool) -> Double {
        guard !isTop else { return Self.opacityValues[0] }
        let from = Self.opacityValues[min(depth, Self.opacityValues.count - 1)]
        let targetDepth = max(0, depth - 1)
        let to = Self.opacityValues[min(targetDepth, Self.opacityValues.count - 1)]
        return from + (to - from) * Double(shiftProgress)
    }

    /// 카드가 최대 visible depth(4)를 넘어가면 페이드 아웃
    private func depthFade(_ effectiveDepth: CGFloat) -> Double {
        let maxDepth = CGFloat(visibleCount - 1)
        guard effectiveDepth > maxDepth else { return 1 }
        return max(0, Double(1 - (effectiveDepth - maxDepth)))
    }

    // MARK: - 드래그 연동

    private var dragYOffset: CGFloat {
        guard dragOffset > 0 else { return 0 }
        return -dragOffset * 0.4
    }

    private var topRotation: Double {
        guard dragOffset > 0 else { return flingRotation }
        return -Double(dragOffset) / 30.0 + flingRotation
    }

    // MARK: - 스와이프 제스처

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let dx = value.translation.width
                if dx >= 0 {
                    // 우측 드래그 — 현재 카드 따라감
                    dragOffset = dx
                    returnProgress = 0
                } else if currentIndex > 0 {
                    // 좌측 드래그 — 현재 카드 고정, 이전 카드 등장
                    dragOffset = 0
                    returnProgress = min(1, abs(dx) / 200)
                }
            }
            .onEnded { value in
                let predicted = value.predictedEndTranslation.width

                if returnProgress > 0 {
                    // 좌스와이프 판정
                    if predicted < -100 || returnProgress > 0.3 {
                        completeBackward()
                    } else {
                        withAnimation(.spring(duration: 0.2)) {
                            returnProgress = 0
                        }
                    }
                } else if predicted > 100, currentIndex < pins.count - 1 {
                    performFlingForward()
                } else {
                    // 마지막 카드이거나 충분히 밀지 않음 → 제자리로. 마지막 카드는 넘길 수 없어 화면에 고정된다.
                    withAnimation(.spring(duration: 0.2)) {
                        dragOffset = 0
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
        withAnimation(.spring(duration: 0.2)) {
            flingXOffset = screenWidth
            flingYOffset = -screenWidth * 0.4
            flingRotation = -20
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

        withAnimation(.spring(duration: 0.2)) {
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
