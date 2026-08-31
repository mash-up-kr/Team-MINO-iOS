import DesignSystem
import SwiftUI

/// 튜토리얼 화면 마크업. Figma `000-1 튜토리얼`(node 2314:95081).
///
/// 스텝 목록을 주입받지 않는 이유: 뷰와 reduce 가 서로 다른 개수를 보면
/// CTA 가 보이는데 눌러도 아무 일이 없는 상태가 된다. 둘 다 ``TutorialStep/all`` 하나만 본다.
struct TutorialContent: View {
    private let steps = TutorialStep.all

    @Binding var pageIndex: Int
    var onTapSkip: () -> Void = {}
    var onTapStart: () -> Void = {}

    private var isLastPage: Bool { pageIndex == steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            MHTopNavigation(title: "튜토리얼", onSkip: isLastPage ? nil : onTapSkip)
            pager
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
        // safeAreaInset 뒤에 깐다 — 앞에 두면 하단 바 영역이 배경 밖으로 밀려 부모 색이 비친다.
        .background(Color.mhBackgroundNormalNormal)
    }

    private var pager: some View {
        TabView(selection: $pageIndex) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                TutorialStepPage(step: step)
                    .tag(index)
            }
        }
        // 기본 인디케이터를 끄고 dot 은 하단 바에서 그린다 — 시안 위치가 기본값과 다르다.
        .tabViewStyle(.page(indexDisplayMode: .never))
        .accessibilityIdentifier("Tutorial.pager")
    }

    /// CTA 는 마지막 스텝에서만 보이되 **자리는 늘 차지한다** — 나타날 때 자리를 밀면
    /// 스텝을 넘길 때마다 위의 카드가 함께 튄다(Figma 도 앞 네 장에 같은 Action Area 를 hidden 으로 뒀다).
    private var bottomBar: some View {
        // 간격 0 — dot 과 버튼 사이 20pt 는 MHActionArea 가 자기 상단 패딩으로 이미 갖고 있다.
        VStack(spacing: 0) {
            MHPaginationDots(count: steps.count, current: pageIndex)

            MHActionArea(main: MHAction("꾹 시작하기", action: onTapStart), safeArea: false)
                .opacity(isLastPage ? 1 : 0)
                .disabled(!isLastPage)
                .accessibilityHidden(!isLastPage)
        }
        .padding(.top, 16)
    }
}

#Preview("첫 스텝") {
    @Previewable @State var pageIndex = 0
    TutorialContent(pageIndex: $pageIndex)
}

#Preview("마지막 스텝") {
    @Previewable @State var pageIndex = TutorialStep.all.count - 1
    TutorialContent(pageIndex: $pageIndex)
}
