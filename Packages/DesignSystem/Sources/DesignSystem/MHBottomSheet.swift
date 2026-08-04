import SwiftUI

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
    let lowFraction: CGFloat      // 0 < low < medium < 1 (init 의 assert 가 보장)
    let mediumFraction: CGFloat

    func height(of detent: MHBottomSheetDetent) -> CGFloat {
        switch detent {
        case .low: containerHeight * lowFraction
        case .medium: containerHeight * mediumFraction
        case .full: containerHeight
        }
    }

    func clampedHeight(_ height: CGFloat) -> CGFloat {
        min(max(height, self.height(of: .low)), self.height(of: .full))
    }

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
/// - **시트 안 세로 스크롤 콘텐츠는 반드시 `MHBottomSheetScrollView` 로 감싼다.** 일반 `ScrollView` 를 쓰면
///   ① low/medium 에서 스크롤이 잠기지 않아 리스트 위 드래그로 시트를 못 움직이고,
///   ② full 에서 항상 "맨 위"로 보고돼 리스트 중간 드래그까지 시트 하강으로 오인된다.
///
/// ```swift
/// ZStack {
///     MapView()
///     MHBottomSheet(detent: $detent, lowFraction: 0.15, mediumFraction: 0.45) {
///         RoomListView()
///     }
/// }
/// ```
public struct MHBottomSheet<ID: Hashable, Content: View>: View {
    @Binding private var detent: MHBottomSheetDetent
    private let lowFraction: CGFloat
    private let mediumFraction: CGFloat
    private let contentID: ID?
    private let content: (ID?) -> Content

    /// 드래그 중 손가락 이동량(아래로 양수) — 손가락을 따라가야 하므로 애니메이션 없이 갱신
    @State private var dragTranslation: CGFloat = 0

    /// 취소 감지용 — 시스템이 제스처를 취소하면 onEnded 없이 이 값만 리셋된다
    @GestureState private var isDragging = false

    /// 스크롤 콘텐츠가 맨 위인가. preference 경유라 최대 1 렌더 늦을 수 있음(실질 무해)
    @State private var scrollIsAtTop = true

    /// full 에서 제스처가 맨 위에서 시작했는가 — 시작 시점에만 판정 (중간 시작 드래그는 끝까지 스크롤 전용)
    @State private var dragBeganAtTop: Bool?

    /// onEnded 정상 종료 표시 — 취소-정리 경로의 이중 스냅 방지 (onChange(isDragging) 참조)
    @State private var dragEndedNormally = false

    @State private var isTransitioningDown = false

    /// 화면에 실제 적용 중인 비율/콘텐츠 ID. 전환 중엔 이전 값으로 동결했다가 내려간 뒤 갱신 —
    /// 새 값이 내려가기 전에 번쩍 보이는 프레임을 없앤다.
    @State private var appliedLow: CGFloat
    @State private var appliedMedium: CGFloat
    @State private var appliedContentID: ID?

    /// 전환 완료 시점에 적용할 최신 목표 — 연속 변경은 여기만 덮어써서 내려가기/올라오기가 1회씩만 일어난다
    @State private var pendingConfig: SheetConfig?

    /// 시트 그림자 스펙(`Shadow/Spread/small`). full 전환 시 색만 clear 로 바꿔 끄기 위해
    /// `mhShadow` 대신 스펙을 직접 쓴다(뷰 identity 유지 — if/else 분기면 드래그 중 재생성됨).
    private var sheetShadow: MHSpreadShadow.Spec { MHSpreadShadow.small.spec }

    /// 공통 초기화 — 검증과 동결 상태 초기화의 단일 출처. public init 들은 전부 여기로 위임한다.
    private init(
        detent: Binding<MHBottomSheetDetent>,
        lowFraction: CGFloat,
        mediumFraction: CGFloat,
        erasedContentID: ID?,
        content: @escaping (ID?) -> Content
    ) {
        assert(0 < lowFraction && lowFraction < mediumFraction && mediumFraction < 1,
               "0 < lowFraction < mediumFraction < 1 이어야 한다")
        self._detent = detent
        self.lowFraction = lowFraction
        self.mediumFraction = mediumFraction
        self.contentID = erasedContentID
        self.content = content
        self._appliedLow = State(initialValue: lowFraction)
        self._appliedMedium = State(initialValue: mediumFraction)
        self._appliedContentID = State(initialValue: erasedContentID)
    }

    /// 콘텐츠 전환 연출(내려갔다 새 높이로 올라오기)이 필요한 화면용.
    /// - Parameter contentID: 시트 콘텐츠의 식별자(화면이 정의한 Hashable — 예: SheetStage enum).
    ///   값이 바뀌면 시트가 **이전 콘텐츠·이전 높이 그대로** 내려갔다가 새 콘텐츠·새 높이로 올라온다.
    /// - Parameter content: 표시할 콘텐츠. **전달받은 id 기준으로 그려야** 전환 중 이전 콘텐츠가 유지된다
    ///   (부모 상태를 직접 읽으면 내려가기 전에 새 콘텐츠가 보인다).
    public init(
        detent: Binding<MHBottomSheetDetent>,
        lowFraction: CGFloat,
        mediumFraction: CGFloat,
        contentID: ID,
        @ViewBuilder content: @escaping (ID) -> Content
    ) {
        // 이 경로에선 appliedContentID 가 항상 non-nil 이라 ?? 는 도달하지 않는다 — 옵셔널 시그니처 맞춤용
        self.init(detent: detent, lowFraction: lowFraction, mediumFraction: mediumFraction,
                  erasedContentID: contentID, content: { id in content(id ?? contentID) })
    }

    public var body: some View {
        GeometryReader { geometry in
            let layout = MHBottomSheetLayout(
                containerHeight: geometry.size.height,
                lowFraction: appliedLow,
                mediumFraction: appliedMedium
            )
            let height = layout.clampedHeight(layout.height(of: detent) - dragTranslation)
            let isFull = height >= layout.height(of: .full)

            sheet(height: height, isFull: isFull)
                .offset(y: isTransitioningDown ? height + geometry.safeAreaInsets.bottom : 0)
                .frame(maxHeight: .infinity, alignment: .bottom)
                // simultaneous 여야 스크롤 콘텐츠 위에서도 드래그를 받는다 —
                // full 에서 리스트 스크롤과의 구분은 onChanged 의 핸드오프 게이팅이 담당
                .simultaneousGesture(dragGesture(layout: layout))
                .onChange(of: isDragging) { _, dragging in
                    // 시스템이 제스처를 취소하면(전화 수신 등) onEnded 없이 isDragging 만 리셋된다 —
                    // 잔류 오프셋을 스냅으로 정리. 한 틱 미뤄 onEnded 와의 실행 순서 의존을 없앤다.
                    guard !dragging else { return }
                    Task { @MainActor in
                        guard !dragEndedNormally else {
                            dragEndedNormally = false
                            return
                        }
                        dragBeganAtTop = nil
                        guard dragTranslation != 0 else { return }
                        withAnimation(.spring(duration: 0.3)) {
                            detent = layout.nearestDetent(to: layout.height(of: detent) - dragTranslation)
                            dragTranslation = 0
                        }
                    }
                }
        }
        .onPreferenceChange(MHSheetScrollAtTopKey.self) { [$scrollIsAtTop] value in
            $scrollIsAtTop.wrappedValue = value
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("MHBottomSheet.sheet")   // QA 자동화(AXe)용 — 시트 존재·상태 검증
        .onChange(of: SheetConfig(contentID: contentID, low: lowFraction, medium: mediumFraction)) { old, new in
            if old.contentID != new.contentID, new.contentID != nil {
                pendingConfig = new
                guard !isTransitioningDown else { return }
                withAnimation(.spring(duration: 0.3)) {
                    isTransitioningDown = true
                } completion: {
                    // 시작 시점 캡처값이 아니라 완료 시점의 최신 예약을 적용해야 연속 탭이 안전하다
                    if let pending = pendingConfig {
                        appliedLow = pending.low
                        appliedMedium = pending.medium
                        appliedContentID = pending.contentID
                        pendingConfig = nil
                    }
                    withAnimation(.spring(duration: 0.35)) {
                        isTransitioningDown = false
                    }
                }
            } else if !isTransitioningDown {
                appliedLow = new.low
                appliedMedium = new.medium
            } else {
                pendingConfig?.low = new.low    // 전환 중 비율 변경도 예약에 합류해야 유실이 없다
                pendingConfig?.medium = new.medium
            }
        }
    }

    /// contentID·비율 변경을 한 번에 감지하기 위한 묶음 (onChange 를 나누면 실행 순서에 따라
    /// 새 비율이 전환 전에 반영돼 번쩍일 수 있다)
    private struct SheetConfig: Equatable {
        let contentID: ID?
        var low: CGFloat
        var medium: CGFloat
    }

    private func sheet(height: CGFloat, isFull: Bool) -> some View {
        VStack(spacing: 0) {
            if !isFull { grabber }
            content(appliedContentID)   // 전환 중엔 이전 ID 로 그려 이전 콘텐츠 유지
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .environment(\.mhSheetScrollEnabled, detent == .full)   // 스크롤은 full 에서만 (애플 지도 규칙)
        }
        .frame(height: height)
        .clipShape(sheetShape(isFull: isFull))
        .background {
            // 시트 표면(흰 면)은 콘텐츠 레이아웃과 분리해 safe area 로 확장한다 — 하단은 항상,
            // 상단은 full 에서. 그림자를 확장된 표면에 걸어야 글로우가 확장 영역 위에 얹혀
            // 회색 띠를 만들지 않는다 (레이아웃·콘텐츠 위치는 safe area 안 그대로).
            sheetShape(isFull: isFull)
                .fill(Color.mhBackgroundNormalNormal)
                .ignoresSafeArea(edges: isFull ? [.top, .bottom] : .bottom)
                .shadow(color: isFull ? .clear : sheetShadow.color, radius: sheetShadow.blur / 2,
                        x: sheetShadow.x, y: sheetShadow.y)
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
            .accessibilityElement()
            .accessibilityIdentifier("MHBottomSheet.grabber")   // QA 자동화(AXe)용 — 드래그 기준점
    }

    private func dragGesture(layout: MHBottomSheetLayout) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { value in
                let dy = value.translation.height
                guard detent == .full else {
                    dragTranslation = dy   // low/medium: 스크롤이 잠겨 있어 모든 드래그가 시트 이동
                    return
                }
                // full: 맨 위에서 "시작한" 제스처만 시트 드래그 (그 외는 리스트 스크롤)
                if dragBeganAtTop == nil { dragBeganAtTop = scrollIsAtTop }
                guard dragBeganAtTop == true, scrollIsAtTop else { return }
                dragTranslation = max(0, dy)   // 위 방향(음수)은 full 에 붙임 — 방향이 되돌아와도 연속 추적
            }
            .onEnded { value in
                dragEndedNormally = true
                let projected: CGFloat
                if detent == .full {
                    let engaged = dragBeganAtTop == true && dragTranslation > 0
                    dragBeganAtTop = nil
                    guard engaged else { return }   // 순수 스크롤 제스처 — 시트 불변
                    projected = value.predictedEndTranslation.height
                } else {
                    projected = value.predictedEndTranslation.height
                }
                let projectedHeight = layout.height(of: detent) - projected
                withAnimation(.spring(duration: 0.3)) {
                    detent = layout.nearestDetent(to: projectedHeight)
                    dragTranslation = 0
                }
            }
    }
}

// MARK: - 전환 연출이 필요 없는 화면용

public extension MHBottomSheet where ID == Never {
    /// 콘텐츠 전환 연출이 필요 없는 화면용 (콘텐츠 고정).
    init(
        detent: Binding<MHBottomSheetDetent>,
        lowFraction: CGFloat,
        mediumFraction: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(detent: detent, lowFraction: lowFraction, mediumFraction: mediumFraction,
                  erasedContentID: nil, content: { _ in content() })
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
