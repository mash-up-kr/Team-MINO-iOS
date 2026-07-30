import SwiftUI
import UIKit

// MARK: - 시트 ↔ 스크롤 연동 채널 (같은 모듈 내부용)

/// MHBottomSheet 가 콘텐츠로 내려주는 "지금 스크롤해도 되는가" (full 에서만 true)
struct MHSheetScrollEnabledKey: EnvironmentKey {
    static let defaultValue = true   // 시트 밖에서 쓰이면 일반 스크롤로 동작
}

/// 래퍼가 시트로 올려 보내는 스크롤 오프셋 (0 = 맨 위)
struct MHSheetScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension EnvironmentValues {
    var mhSheetScrollEnabled: Bool {
        get { self[MHSheetScrollEnabledKey.self] }
        set { self[MHSheetScrollEnabledKey.self] = newValue }
    }
}

// MARK: - MHBottomSheetScrollView

/// `MHBottomSheet` 안에서 세로 스크롤 콘텐츠를 쓸 때 `ScrollView` 대신 사용하는 래퍼.
/// 시트-스크롤 드래그 연동(애플 지도 규칙)을 담당한다:
/// - `low`/`medium`: 스크롤 잠김 → 리스트 위 드래그도 시트 이동
/// - `full`: 스크롤 활성. 리스트 맨 위에서 시작한 아래 방향 드래그는 시트 하강(핸드오프)
///
/// 스크롤이 없는 고정 콘텐츠는 이 래퍼 없이 일반 뷰로 넣으면 된다(시트 드래그가 그대로 동작).
public struct MHBottomSheetScrollView<Inner: View>: View {
    @Environment(\.mhSheetScrollEnabled) private var scrollEnabled
    private let inner: Inner

    /// 현재 스크롤 오프셋 (0 = 맨 위). 시트에는 preference 로 전달된다.
    @State private var offset: CGFloat = 0

    public init(@ViewBuilder content: () -> Inner) {
        self.inner = content()
    }

    public var body: some View {
        ScrollView {
            inner
                .background(ScrollViewIntrospector { offset = $0 })
        }
        .scrollDisabled(!scrollEnabled)
        .preference(key: MHSheetScrollOffsetKey.self, value: offset)
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
        guard window != nil, observation == nil else { return }

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
