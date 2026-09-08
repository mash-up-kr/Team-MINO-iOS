import SwiftUI
import UIKit

/// MHBottomSheet 가 콘텐츠로 내려주는 "지금 스크롤해도 되는가" (full 에서만 true)
struct MHSheetScrollEnabledKey: EnvironmentKey {
    static let defaultValue = true   // 시트 밖에서 쓰이면 일반 스크롤로 동작
}

/// 시트가 래퍼에 내려주는 "스크롤이 맨 위인가" 상자. 래퍼가 쓰고, 시트의 드래그 판정이 읽는다.
///
/// `@State` 로 받아 preference 로 올려 보내지 않는 이유: 오프셋은 UIScrollView KVO 로 들어오는데
/// 그 콜백은 SwiftUI 의 뷰 갱신 도중(스크롤 뷰 레이아웃 안)에 불려, **거기서 한 `@State` 쓰기가
/// 버려진다**("Modifying state during view update"). 래퍼는 false 로 바꿨다고 믿는데 시트는 끝까지
/// true 를 보고 있어, 리스트 중간에서 아래로 드래그해도 시트가 내려갔다(iOS 18·26 재현).
/// 참조 상자에 바로 쓰면 뷰 갱신에 얽히지 않고, 드래그 판정에만 쓰여 뷰 무효화도 일으키지 않는다.
/// 기본 true — 래퍼 없는(스크롤 없는) 콘텐츠에서 시트 드래그가 항상 통해야 한다.
@MainActor
final class MHSheetScrollState {
    var isAtTop = true
}

struct MHSheetScrollStateKey: EnvironmentKey {
    static let defaultValue: MHSheetScrollState? = nil   // 시트 밖에서 쓰이면 보고할 곳이 없다
}

extension EnvironmentValues {
    var mhSheetScrollEnabled: Bool {
        get { self[MHSheetScrollEnabledKey.self] }
        set { self[MHSheetScrollEnabledKey.self] = newValue }
    }

    var mhSheetScrollState: MHSheetScrollState? {
        get { self[MHSheetScrollStateKey.self] }
        set { self[MHSheetScrollStateKey.self] = newValue }
    }
}

// MARK: - MHBottomSheetScrollView

/// `MHBottomSheet` 안에서 세로 스크롤 콘텐츠를 쓸 때 `ScrollView` 대신 사용하는 래퍼.
/// 시트-스크롤 드래그 연동(애플 지도 규칙)을 담당한다:
/// - `low`/`medium`: 스크롤 잠김 → 리스트 위 드래그도 시트 이동
/// - `full`: 스크롤 활성. 리스트 맨 위에서 시작한 아래 방향 드래그는 시트 하강(핸드오프)
/// - 핸드오프를 위해 내부 스크롤의 바운스를 끄므로 **pull-to-refresh 는 지원하지 않는다.**
///
/// 스크롤이 없는 고정 콘텐츠는 이 래퍼 없이 일반 뷰로 넣으면 된다(시트 드래그가 그대로 동작).
public struct MHBottomSheetScrollView<Inner: View>: View {
    @Environment(\.mhSheetScrollEnabled) private var scrollEnabled
    @Environment(\.mhSheetScrollState) private var scrollState
    private let inner: Inner
    private let onOffsetChange: (@MainActor (CGFloat) -> Void)?

    public init(
        onOffsetChange: (@MainActor (CGFloat) -> Void)? = nil,
        @ViewBuilder content: () -> Inner
    ) {
        self.onOffsetChange = onOffsetChange
        self.inner = content()
    }

    public var body: some View {
        // 클로저는 첫 makeUIView 때 한 번만 붙잡히므로 상자를 지역에 떠서 넘긴다 — 뷰 복사본의
        // 환경을 나중에 읽는 것보다 캡처가 분명하다.
        let scrollState = self.scrollState
        ScrollView {
            inner
                .background(ScrollViewIntrospector { offset in
                    // 맨 위 판정(0.5pt 임계). 뷰 상태가 아니라 상자에 쓰므로 매 오프셋마다 써도 재평가가 없다.
                    scrollState?.isAtTop = offset <= 0.5
                    onOffsetChange?(offset)
                })
        }
        .scrollDisabled(!scrollEnabled)
        // 래퍼가 빠지면(콘텐츠 교체) 기본값으로 되돌린다 — 뒤이어 오는 스크롤 없는 콘텐츠에서도
        // 시트 드래그가 통해야 한다. 새 래퍼가 오면 KVO `.initial` 이 실제 오프셋으로 다시 쓴다.
        .onDisappear { scrollState?.isAtTop = true }
    }
}

// MARK: - UIScrollView 연동 (바운스 제거 + 오프셋 관측)

/// 감싸는 UIScrollView 를 찾아 두 가지를 한다 — 전부 iOS 17 호환 UIKit 경로다.
/// 1. `bounces = false`: 맨 위에서 아래로 당길 때 고무줄이 드래그를 소비하면 시트 핸드오프가 불가능
///    (부작용: pull-to-refresh 불가 — 기획에 없음)
/// 2. `contentOffset` KVO: 스크롤 오프셋을 실시간 보고 — GeometryReader 마커 방식은
///    iOS 18+ 의 새 ScrollView 구현에서 스크롤 중 갱신되지 않아 쓰지 않는다(시뮬레이터 확인).
private struct ScrollViewIntrospector: UIViewRepresentable {
    let onOffsetChange: @MainActor (CGFloat) -> Void

    func makeUIView(context: Context) -> IntrospectorView {
        IntrospectorView(onOffsetChange: onOffsetChange)
    }

    func updateUIView(_ uiView: IntrospectorView, context: Context) {}
}

private final class IntrospectorView: UIView {
    private let onOffsetChange: @MainActor (CGFloat) -> Void
    private var observation: NSKeyValueObservation?

    init(onOffsetChange: @escaping @MainActor (CGFloat) -> Void) {
        self.onOffsetChange = onOffsetChange
        super.init(frame: .zero)
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) 미지원") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // 윈도우 (재)진입마다 재탐색 — SwiftUI 가 내부 UIScrollView 를 교체해도
        // (iOS 18 의 ScrollView 재구현 같은 내부 변경) 옛 인스턴스를 계속 관찰하지 않게 한다.
        // 창을 **떠날 때도** 끊는다 — 사라진 래퍼의 관찰이 살아남아 상자에 계속 쓰면 안 된다.
        observation = nil
        guard window != nil else { return }

        var view: UIView? = superview
        while let current = view {
            if let scrollView = current as? UIScrollView {
                scrollView.bounces = false
                let handler = onOffsetChange
                observation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { scrollView, _ in
                    // contentOffset 변경은 항상 main 스레드에서 온다
                    let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
                    MainActor.assumeIsolated { handler(offset) }
                }
                return
            }
            view = current.superview
        }
    }
}

#Preview("MHBottomSheetScrollView") {
    MHBottomSheetScrollView {
        VStack(spacing: 12) {
            ForEach(0..<20, id: \.self) { i in
                Text("항목 \(i)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.mhFillAlternative, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
    }
}
