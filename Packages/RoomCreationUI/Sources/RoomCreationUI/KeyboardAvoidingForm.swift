import DesignSystem
import SwiftUI
import UIKit

/// 입력 폼 화면의 스크롤·키보드·고정 바 배치를 한 곳에 모은 껍데기.
///
/// 쓰는 화면은 내용만 채우면 된다. 여기서 보장하는 것은 셋이다.
/// - 포커스된 필드를 키보드 위로 **직접 스크롤해** 올린다
/// - 하단 바는 화면 바닥에 고정돼 키보드를 따라 올라오지 않는다
/// - 상단바는 스크롤과 무관하게 고정되고, 그 아래로 콘텐츠가 비치지 않는다
///
/// 필드는 ``MHTextField``·``MHTextArea`` 의 `identifier` 를 그대로 `.id(_:)` 로도 달아야 한다.
/// 포커스 통지(``MHFocusedFieldKey``)가 그 문자열로 올라오고, 스크롤 목적지도 그 값으로 찾는다.
struct KeyboardAvoidingForm<Content: View, TopBar: View, BottomBar: View>: View {
    private let content: Content
    private let topBar: TopBar
    private let bottomBar: BottomBar

    /// 포커스된 입력 필드의 identifier — 스크롤로 띄울 대상.
    @State private var focusedField: String?
    /// 하단 바의 높이. 오버레이라 스크롤뷰가 모르므로 콘텐츠 아래 여백으로 직접 비켜 준다.
    @State private var bottomBarHeight: CGFloat = 0

    /// 키보드 애니메이션이 끝나 스크롤뷰 인셋이 안정되기까지 기다릴 시간.
    ///
    /// 시스템이 알려주는 **실제** 애니메이션 시간을 쓴다. 상수로 박으면 기기·iOS 버전마다 다른 길이를
    /// 추측하는 셈이라, 느린 기기에서 인셋이 아직 안 잡힌 채 스크롤해 목적지가 어긋난다.
    /// 첫 포커스처럼 알림을 아직 못 받은 때를 위해 표준값으로 시작한다.
    @State private var insetSettleDelay: TimeInterval = 0.3

    init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder topBar: () -> TopBar,
        @ViewBuilder bottomBar: () -> BottomBar
    ) {
        self.content = content()
        self.topBar = topBar()
        self.bottomBar = bottomBar()
    }

    var body: some View {
        // 스크롤뷰가 **화면 루트**여야 한다. 상단바를 VStack 형제로 두면 키보드가 올라올 때 그 VStack 이
        // 키보드 높이만큼 줄어 콘텐츠가 잘려 나간다. inset 으로 얹으면 키보드 인셋이 스크롤뷰에 걸린다.
        ScrollViewReader { proxy in
            ScrollView {
                content.padding(.bottom, bottomBarHeight)
            }
            .safeAreaInset(edge: .top) {
                // 상단바에 배경이 없으면 inset 아래로 콘텐츠가 흘러 비친다.
                topBar.background(Color.mhBackgroundNormalNormal)
            }
            .overlay { pinnedBottomBar }
            .onPreferenceChange(MHFocusedFieldKey.self) { focused in
                Task { @MainActor in focusedField = focused }
            }
            // 읽었으면 여기서 소비한다. 그냥 두면 이 폼 바깥까지 올라가, 한 화면에 폼이 둘 이상일 때
            // 서로의 포커스가 섞인다(`reduce` 가 먼저 만난 값을 쥔다).
            .transformPreference(MHFocusedFieldKey.self) { $0 = nil }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
                guard let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
                      duration > 0
                else { return }
                insetSettleDelay = duration
            }
            .task(id: focusedField) { await revealFocusedField(with: proxy) }
        }
        .background(Color.mhBackgroundNormalNormal)
    }

    /// 화면 바닥에 못박은 하단 바.
    ///
    /// `safeAreaInset(edge: .bottom)` 으로 붙이면 키보드 위로 따라 올라와 입력 내내 필드 밑에 붙어
    /// 다니고, 포커스가 풀릴 때 화면 중간에서 내려오는 것도 어색하다.
    ///
    /// 바닥 정렬만으로는 부족하다 — 오버레이도 안전영역 **안에서** 정렬돼 키보드만큼 위로 붙는다.
    /// 화면을 채운 뒤 키보드 인셋을 무시해야 비로소 고정된다.
    private var pinnedBottomBar: some View {
        bottomBar
            .background {
                GeometryReader { bar in
                    Color.clear
                        .onChange(of: bar.size.height, initial: true) { _, height in
                            bottomBarHeight = height
                        }
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    /// 포커스된 필드를 키보드 위로 스크롤해 올린다.
    ///
    /// 평범한 `ScrollView` 는 포커스된 필드로 자동 스크롤하지 않는다 — 그건 `List`/`Form` 만의
    /// 동작이다. 직접 하지 않으면 필드가 키보드 뒤에 남는다(화면이 짧을수록 심하다).
    ///
    /// 키보드가 올라와 스크롤뷰 인셋이 갱신된 **뒤에** 스크롤해야 한다. 곧바로 하면 아직 전체 높이
    /// 기준이라 목표 지점이 키보드 뒤로 들어간다.
    private func revealFocusedField(with proxy: ScrollViewProxy) async {
        guard let focusedField else { return }
        // 취소(포커스 이동·화면 이탈)는 스크롤할 이유가 사라진 것이므로 그냥 빠져나간다.
        do { try await Task.sleep(for: .seconds(insetSettleDelay)) } catch { return }
        withAnimation { proxy.scrollTo(focusedField, anchor: .center) }
    }
}
