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
    /// 키보드가 올라올 때 입력칸을 끌어올리기 위해 들고 있는 스크롤 뷰.
    private weak var scrollView: UIScrollView?
    private var keyboardObservers: [NSObjectProtocol] = []
    /// 키보드가 떠 있는 동안의 프레임. 스크롤로 입력칸을 지나쳐 둔 뒤 **다시 타이핑할 때**
    /// 되돌리려면 그 시점에도 키보드 위치를 알아야 하는데, 알림은 그때 오지 않는다.
    private var keyboardFrame: CGRect?
    /// 타이핑 되돌리기 예약 중인가. 글자마다 예약이 쌓이면 한 프레임에 여러 번 돈다.
    private var revealScheduled = false

    init(onOffsetChange: @escaping @MainActor (CGFloat) -> Void) {
        self.onOffsetChange = onOffsetChange
        super.init(frame: .zero)
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) 미지원") }

    /// 커서 줄 아래로 더 확보할 여유. 글자수 카운터가 그 아래에 붙어 있어 이만큼은 함께 보여야 한다.
    private static let revealMargin: CGFloat = 44

    /// 키보드가 덮는 만큼을 스크롤 뷰의 **하단 인셋**으로 돌려준다.
    ///
    /// 오프셋을 직접 계산해 밀어넣던 방식은 입력칸이 커지는 동안 레이아웃과 서로 밀고 당겨
    /// **글자마다 두 상태가 번갈아 나타났다**(실기기 재현). 인셋만 세워 두면 가시 영역의 정의가
    /// 한 곳으로 모여, 아래 `scrollRectToVisible` 이 "이미 보이면 아무것도 안 함"으로 동작한다.
    ///
    /// 시트는 키보드가 뜨면 컨테이너 자체가 줄어들어(실측 759 → 413) 키보드 몫은 대개 이미 빠져
    /// 있다. 남는 건 그 위에 얹히는 액세서리 툴바("완료" 줄)뿐이라 보통 그만큼만 잡힌다.
    @MainActor
    private func applyKeyboardInset() {
        guard let scrollView, let window = scrollView.window else { return }
        let bottom: CGFloat
        if let keyboardFrame {
            let keyboard = window.convert(keyboardFrame, from: nil)
            let scrollFrame = scrollView.convert(scrollView.bounds, to: window)
            bottom = max(0, scrollFrame.maxY - keyboard.minY)
        } else {
            bottom = 0
        }
        guard abs(scrollView.contentInset.bottom - bottom) > 0.5 else { return }
        scrollView.contentInset.bottom = bottom
        scrollView.verticalScrollIndicatorInsets.bottom = bottom
    }

    /// 입력칸(정확히는 **커서가 있는 줄**)을 보이는 자리로 끌어온다.
    ///
    /// `scrollRectToVisible` 은 이미 보이면 아무것도 하지 않아 **여러 번 불러도 안전하다** —
    /// 글자마다 불려도 튀지 않는다. 목표를 입력칸 전체가 아니라 커서 줄로 잡는 이유는, 칸이
    /// 길어지면 전체를 보이게 하려다 위쪽으로 끌려가 정작 치는 자리가 밀려나기 때문이다.
    @MainActor
    private func revealCaret(animated: Bool) {
        guard let scrollView, let responder = Self.firstResponder(in: scrollView) else { return }
        applyKeyboardInset()

        let rect: CGRect
        if let textView = responder as? UITextView, let range = textView.selectedTextRange {
            rect = textView.convert(textView.caretRect(for: range.end), to: scrollView)
        } else {
            rect = responder.convert(responder.bounds, to: scrollView)
        }
        // 커서 줄 아래로 조금 더 확보한다 — 글자수 카운터가 바로 아래에 붙어 있다.
        scrollView.scrollRectToVisible(rect.insetBy(dx: 0, dy: -Self.revealMargin), animated: animated)
    }

    /// 되돌리기를 **레이아웃 뒤로 한 번만** 미룬다. `textDidChange` 시점엔 커진 입력칸이 아직
    /// 반영되지 않아 커서 위치도 `contentSize` 도 옛 값이다. 글자마다 예약이 쌓이지 않게 합친다.
    @MainActor
    private func scheduleRevealAfterLayout(animated: Bool) {
        guard !revealScheduled else { return }
        revealScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.revealScheduled = false
            self?.revealCaret(animated: animated)
        }
    }

    private static func firstResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder { return view }
        for subview in view.subviews {
            if let found = firstResponder(in: subview) { return found }
        }
        return nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // 윈도우 (재)진입마다 재탐색 — SwiftUI 가 내부 UIScrollView 를 교체해도
        // (iOS 18 의 ScrollView 재구현 같은 내부 변경) 옛 인스턴스를 계속 관찰하지 않게 한다.
        // 창을 **떠날 때도** 끊는다 — 사라진 래퍼의 관찰이 살아남아 상자에 계속 쓰면 안 된다.
        observation = nil
        scrollView = nil
        // 창을 떠나면 키보드 구독도 끊는다 — deinit 은 nonisolated 라 여기서 정리한다.
        keyboardObservers.forEach(NotificationCenter.default.removeObserver)
        keyboardObservers = []
        keyboardFrame = nil
        guard window != nil else { return }

        var view: UIView? = superview
        while let current = view {
            if let scrollView = current as? UIScrollView {
                scrollView.bounces = false
                self.scrollView = scrollView
                let handler = onOffsetChange
                observation = scrollView.observe(\.contentOffset, options: [.initial, .new]) { scrollView, _ in
                    // contentOffset 변경은 항상 main 스레드에서 온다
                    let offset = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
                    MainActor.assumeIsolated { handler(offset) }
                }
                if keyboardObservers.isEmpty {
                    let center = NotificationCenter.default
                    keyboardObservers = [
                        center.addObserver(
                            forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main
                        ) { [weak self] note in
                            // Notification 은 Sendable 이 아니라 밖으로 넘기지 않고 필요한 값만 뽑는다.
                            let info = note.userInfo
                            let frame = info?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
                            MainActor.assumeIsolated {
                                self?.keyboardFrame = frame
                                // 레이아웃(시트 축소)이 반영된 뒤 재야 인셋·커서 위치가 맞는다.
                                self?.scheduleRevealAfterLayout(animated: true)
                            }
                        },
                        center.addObserver(
                            forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main
                        ) { [weak self] _ in
                            MainActor.assumeIsolated {
                                self?.keyboardFrame = nil
                                self?.applyKeyboardInset()   // 인셋을 되돌린다
                            }
                        },
                        // 키보드를 띄운 채 페이지를 훑어보는 건 그대로 두되(스크롤 자유),
                        // **다시 타이핑을 시작하면** 입력칸으로 돌아온다. 무엇을 치고 있는지
                        // 안 보이는 상태로 글자가 들어가는 것을 막는다.
                        center.addObserver(
                            forName: UITextView.textDidChangeNotification, object: nil, queue: .main
                        ) { [weak self] _ in
                            // 알림은 전역이라 우리 스크롤 뷰 안의 응답자일 때만 반응한다
                            // (revealFirstResponder 의 firstResponder 탐색이 그 판정을 겸한다).
                            MainActor.assumeIsolated { self?.scheduleRevealAfterLayout(animated: false) }
                        },
                    ]
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
