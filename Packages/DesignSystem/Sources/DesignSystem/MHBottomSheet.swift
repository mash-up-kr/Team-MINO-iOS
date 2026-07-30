import SwiftUI

// MARK: - Detent

/// 바텀시트 높이 단계. `low`(최저) → `medium`(중간) → `full`(전체 화면).
public enum MHBottomSheetDetent: CaseIterable, Equatable, Sendable {
    case low
    case medium
    case full
}

// MARK: - Layout (순수 로직)

/// 높이 계산·스냅 판정. 뷰와 분리해 단위 테스트 대상으로 둔다.
struct MHBottomSheetLayout: Equatable {
    let containerHeight: CGFloat
    /// `low` 단계 높이 = 컨테이너 높이 × lowFraction (0 < low < medium < 1)
    let lowFraction: CGFloat
    /// `medium` 단계 높이 = 컨테이너 높이 × mediumFraction
    let mediumFraction: CGFloat

    func height(of detent: MHBottomSheetDetent) -> CGFloat {
        switch detent {
        case .low: containerHeight * lowFraction
        case .medium: containerHeight * mediumFraction
        case .full: containerHeight
        }
    }

    /// 드래그 중 표시 높이 — `low` 아래·`full` 위로 못 넘게 클램프
    func clampedHeight(_ height: CGFloat) -> CGFloat {
        min(max(height, self.height(of: .low)), self.height(of: .full))
    }

    /// 주어진 높이(관성 반영된 예상 최종 높이)에서 가장 가까운 단계로 스냅
    func nearestDetent(to height: CGFloat) -> MHBottomSheetDetent {
        MHBottomSheetDetent.allCases.min {
            abs(self.height(of: $0) - height) < abs(self.height(of: $1) - height)
        } ?? .medium
    }
}

// MARK: - MHBottomSheet

/// 드래그로 3단계(`low`/`medium`/`full`) 높이를 오가는 바텀시트.
/// 지도를 가리지 않는 비모달(딤 없음) 시트로, 띄우는 화면의 ZStack 안에 겹쳐 놓는 컴포넌트다.
///
/// - `low`·`medium` 높이는 컨테이너 높이 대비 비율로 화면마다 지정한다. `full`은 컨테이너 전체.
/// - 상단 코너는 radius 20, `full`에서는 0으로 펴지고 그래버도 사라져 전체 화면이 된다(Figma `003-1-1` 시리즈).
/// - 시트 위에 얹는 버튼(닫기 등)은 화면마다 달라서 컴포넌트에 포함하지 않는다 — 각 화면이 overlay로 올린다.
///
/// ```swift
/// ZStack {
///     MapView()
///     MHBottomSheet(detent: $detent, lowFraction: 0.15, mediumFraction: 0.45) {
///         RoomListView()
///     }
/// }
/// ```
public struct MHBottomSheet<Content: View>: View {
    @Binding private var detent: MHBottomSheetDetent
    private let lowFraction: CGFloat
    private let mediumFraction: CGFloat
    private let contentID: AnyHashable?
    private let content: (AnyHashable?) -> Content

    /// 드래그 중 손가락 이동량(아래로 양수). 손가락을 따라가야 하므로 애니메이션 없이 갱신한다.
    @State private var dragTranslation: CGFloat = 0

    /// 콘텐츠 전환 중 시트를 화면 아래로 내려 보내는 상태. `contentID` 가 바뀌면
    /// 내림 → (새 콘텐츠·새 높이로) 올림 시퀀스를 탄다.
    @State private var isTransitioningDown = false

    /// 화면에 실제 적용 중인 비율/콘텐츠 ID. 전환 중엔 이전 값으로 동결했다가 내려간 뒤 갱신한다 —
    /// 부모가 contentID 와 비율·콘텐츠를 동시에 바꿔도 "새 높이·새 콘텐츠가 번쩍 보였다 내려가는" 프레임이 없다.
    @State private var appliedLow: CGFloat
    @State private var appliedMedium: CGFloat
    @State private var appliedContentID: AnyHashable?

    /// 시트 그림자 스펙(`Shadow/Spread/small`). full 전환 시 색만 clear 로 바꿔 끄기 위해
    /// `mhShadow` 대신 스펙을 직접 쓴다(뷰 identity 유지 — if/else 분기면 드래그 중 재생성됨).
    private var sheetShadow: MHSpreadShadow.Spec { MHSpreadShadow.small.spec }

    /// 콘텐츠 전환 연출(내려갔다 새 높이로 올라오기)이 필요한 화면용.
    /// - Parameter contentID: 시트 콘텐츠의 식별자. 값이 바뀌면 시트가 **이전 콘텐츠·이전 높이 그대로**
    ///   내려갔다가 새 콘텐츠·새 높이로 올라온다(방 상세 → 장소 상세 같은 전환).
    /// - Parameter content: 표시할 콘텐츠. **전달받은 id 기준으로 그려야** 전환 중 이전 콘텐츠가 유지된다
    ///   (부모 상태를 직접 읽으면 내려가기 전에 새 콘텐츠가 보인다).
    public init(
        detent: Binding<MHBottomSheetDetent>,
        lowFraction: CGFloat,
        mediumFraction: CGFloat,
        contentID: AnyHashable,
        @ViewBuilder content: @escaping (AnyHashable) -> Content
    ) {
        self._detent = detent
        self.lowFraction = lowFraction
        self.mediumFraction = mediumFraction
        self.contentID = contentID
        self.content = { id in content(id ?? contentID) }
        self._appliedLow = State(initialValue: lowFraction)
        self._appliedMedium = State(initialValue: mediumFraction)
        self._appliedContentID = State(initialValue: contentID)
    }

    /// 콘텐츠 전환 연출이 필요 없는 화면용.
    public init(
        detent: Binding<MHBottomSheetDetent>,
        lowFraction: CGFloat,
        mediumFraction: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._detent = detent
        self.lowFraction = lowFraction
        self.mediumFraction = mediumFraction
        self.contentID = nil
        self.content = { _ in content() }
        self._appliedLow = State(initialValue: lowFraction)
        self._appliedMedium = State(initialValue: mediumFraction)
        self._appliedContentID = State(initialValue: nil)
    }

    public var body: some View {
        GeometryReader { geometry in
            let layout = MHBottomSheetLayout(
                containerHeight: geometry.size.height,
                lowFraction: appliedLow,        // 전환 중엔 이전 비율로 동결됨
                mediumFraction: appliedMedium
            )
            let height = layout.clampedHeight(layout.height(of: detent) - dragTranslation)
            let isFull = height >= layout.height(of: .full)

            sheet(height: height, isFull: isFull)
                // 전환 중엔 시트 높이 + 하단 safe area 만큼 내려 화면 밖으로
                .offset(y: isTransitioningDown ? height + geometry.safeAreaInsets.bottom : 0)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .gesture(dragGesture(layout: layout))
        }
        .onChange(of: SheetConfig(contentID: contentID, low: lowFraction, medium: mediumFraction)) { old, new in
            if old.contentID != new.contentID, new.contentID != nil {
                // 콘텐츠 전환: 이전 콘텐츠·이전 높이 그대로 내려간 뒤, 화면 밖에서 교체하고 올라온다
                withAnimation(.spring(duration: 0.3)) {
                    isTransitioningDown = true
                } completion: {
                    appliedLow = new.low
                    appliedMedium = new.medium
                    appliedContentID = new.contentID
                    withAnimation(.spring(duration: 0.35)) {
                        isTransitioningDown = false
                    }
                }
            } else if !isTransitioningDown {
                // 전환 연출 없이 비율만 바뀐 경우는 즉시 반영
                appliedLow = new.low
                appliedMedium = new.medium
            }
        }
    }

    /// contentID·비율 변경을 한 번에 감지하기 위한 묶음 (onChange 를 나누면 실행 순서에 따라
    /// 새 비율이 전환 전에 반영돼 번쩍일 수 있다)
    private struct SheetConfig: Equatable {
        let contentID: AnyHashable?
        let low: CGFloat
        let medium: CGFloat
    }

    /// `full`에서는 상단 코너가 0으로 펴지고 그래버도 사라진다(Figma `003-1-3`).
    private func sheet(height: CGFloat, isFull: Bool) -> some View {
        VStack(spacing: 0) {
            if !isFull { grabber }
            content(appliedContentID)   // 전환 중엔 이전 ID 로 그려 이전 콘텐츠 유지
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: height)
        .clipShape(sheetShape(isFull: isFull))   // 콘텐츠를 상단 코너에 맞게 클립
        .background {
            // 시트 표면(흰 면). 콘텐츠 레이아웃과 분리해 표면만 safe area 로 확장한다 —
            // 하단은 항상 홈 인디케이터 영역까지(탭바가 있으면 탭바가 덮어 무해),
            // 상단은 full 에서 상태바 영역까지 → 화면과 이어진 전체 화면으로 보인다.
            // 그림자는 확장된 표면에 걸어 글로우가 확장 영역 위에 얹히지 않게 한다.
            sheetShape(isFull: isFull)
                .fill(Color.mhBackgroundNormalNormal)
                .ignoresSafeArea(edges: isFull ? [.top, .bottom] : .bottom)
                .shadow(color: isFull ? .clear : sheetShadow.color, radius: sheetShadow.blur / 2,
                        x: sheetShadow.x, y: sheetShadow.y)   // full 은 화면과 한 몸 — 그림자 없음
        }
        .animation(.spring(duration: 0.3), value: detent)
    }

    private func sheetShape(isFull: Bool) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: isFull ? 0 : 20,
            topTrailingRadius: isFull ? 0 : 20,
            style: .continuous
        )
    }

    private var grabber: some View {
        Capsule()
            .fill(.mhFillNormal)
            .frame(width: 38, height: 4)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .contentShape(Rectangle())
    }

    private func dragGesture(layout: MHBottomSheetLayout) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                // 관성 반영: 예상 최종 위치 기준으로 가장 가까운 단계에 스냅
                let projectedHeight = layout.height(of: detent) - value.predictedEndTranslation.height
                withAnimation(.spring(duration: 0.3)) {
                    detent = layout.nearestDetent(to: projectedHeight)
                    dragTranslation = 0
                }
            }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewHost: View {
        @State private var detent: MHBottomSheetDetent = .low

        var body: some View {
            ZStack {
                Color.mhFillAlternative.ignoresSafeArea()
                MHBottomSheet(detent: $detent, lowFraction: 0.15, mediumFraction: 0.45) {
                    Text("방 리스트")
                        .font(.system(size: 24, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .frame(height: 60)
                }
            }
        }
    }
    return PreviewHost()
}
