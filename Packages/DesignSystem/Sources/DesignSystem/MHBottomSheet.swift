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
/// - 상단 코너는 radius 20, `full`에서는 0으로 펴져 전체 화면이 된다(Figma `003-1-1` 시리즈).
/// - `onCloseTap`을 넘기면 오른쪽 위에 플로팅 닫기 버튼 영역이 표시된다(X 아이콘은 추후 삽입).
///
/// ```swift
/// ZStack {
///     MapView()
///     MHBottomSheet(detent: $detent, lowFraction: 0.15, mediumFraction: 0.45,
///                   onCloseTap: { store.send(.tapClose) }) {
///         RoomListView()
///     }
/// }
/// ```
public struct MHBottomSheet<Content: View>: View {
    @Binding private var detent: MHBottomSheetDetent
    private let lowFraction: CGFloat
    private let mediumFraction: CGFloat
    private let onCloseTap: (() -> Void)?
    private let content: Content

    /// 드래그 중 손가락 이동량(아래로 양수). 손가락을 따라가야 하므로 애니메이션 없이 갱신한다.
    @State private var dragTranslation: CGFloat = 0

    public init(
        detent: Binding<MHBottomSheetDetent>,
        lowFraction: CGFloat,
        mediumFraction: CGFloat,
        onCloseTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self._detent = detent
        self.lowFraction = lowFraction
        self.mediumFraction = mediumFraction
        self.onCloseTap = onCloseTap
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geometry in
            let layout = MHBottomSheetLayout(
                containerHeight: geometry.size.height,
                lowFraction: lowFraction,
                mediumFraction: mediumFraction
            )
            let height = layout.clampedHeight(layout.height(of: detent) - dragTranslation)
            let isFull = height >= layout.height(of: .full)

            sheet(height: height, cornerRadius: isFull ? 0 : 20)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .gesture(dragGesture(layout: layout))
        }
    }

    private func sheet(height: CGFloat, cornerRadius: CGFloat) -> some View {
        VStack(spacing: 0) {
            grabber
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(height: height)
        .background(.mhBackgroundNormalNormal)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: cornerRadius,
            topTrailingRadius: cornerRadius,
            style: .continuous
        ))
        .mhShadow(spread: .small)
        .overlay(alignment: .topTrailing) { closeButton }
        .animation(.spring(duration: 0.3), value: detent)
    }

    private var grabber: some View {
        Capsule()
            .fill(.mhFillNormal)
            .frame(width: 38, height: 4)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .contentShape(Rectangle())
    }

    /// 플로팅 닫기 버튼 영역. X 아이콘은 추후 삽입 — 지금은 영역(원형)만 그린다.
    @ViewBuilder private var closeButton: some View {
        if let onCloseTap {
            Button(action: onCloseTap) {
                Circle()
                    .strokeBorder(.mhLineNormalNeutral)
                    .background(Circle().fill(.mhBackgroundNormalNormal))
                    .frame(width: 40, height: 40)
                    .mhShadow(spread: .small)
            }
            .accessibilityLabel("닫기")
            .accessibilityIdentifier("mh_bottom_sheet_close_button")
            .padding(.top, 40)
            .padding(.trailing, 20)
        }
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
                MHBottomSheet(detent: $detent, lowFraction: 0.15, mediumFraction: 0.45,
                              onCloseTap: {}) {
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
