import DesignSystem
import SwiftUI

/// 튜토리얼 화면 마크업. Figma `000-1 튜토리얼`(node 2314:95081).
///
/// 다섯 스텝을 좌우로 넘겨 보는 한 화면이다. 마지막 스텝에서만 상단 '건너뛰기'가 빠지고
/// 하단 CTA 가 나타난다 — Figma 도 앞 네 장에 같은 Action Area 를 `hidden` 으로 놓아 두었다.
///
/// Store 를 모른다 — 값과 콜백만 받는다.
struct TutorialContent: View {
    /// Figma: 마스코트 90×117.14, 화면 오른쪽 밖으로 6pt 걸쳐 잘린다. y 는 상단 안전영역 기준 71.
    private static let mascotSize = CGSize(width: 90, height: 117.143)

    let steps: [TutorialStep]
    @Binding var pageIndex: Int
    var onTapSkip: () -> Void = {}
    var onTapStart: () -> Void = {}

    private var isLastPage: Bool { pageIndex == steps.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            MHTopNavigation(title: "튜토리얼", onSkip: isLastPage ? nil : onTapSkip)
            pager
        }
        .background(Color.mhBackgroundNormalNormal)
        // 다섯 스텝이 모두 같은 자리에 두는 장식이라 페이저 밖에 둔다 — 안에 넣으면 스와이프마다 함께 밀린다.
        .overlay(alignment: .topTrailing) { mascot }
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    private var pager: some View {
        TabView(selection: $pageIndex) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                TutorialStepPage(step: step)
                    .tag(index)
            }
        }
        // 기본 인디케이터를 끄고 dot 은 하단 바에서 그린다 — 시안의 위치(카드 아래 16)가 기본값과 다르다.
        .tabViewStyle(.page(indexDisplayMode: .never))
        .accessibilityIdentifier("Tutorial.pager")
    }

    /// 화면 오른쪽에서 빼꼼 내다보는 꾹 캐릭터.
    ///
    /// DS 에셋은 왼쪽에서 내다보는 방향이라 좌우를 뒤집는다(Figma 도 같은 벡터를 뒤집어 썼다).
    private var mascot: some View {
        Image(dsImage: "homeMascot")
            .resizable()
            .scaledToFit()
            .frame(width: Self.mascotSize.width, height: Self.mascotSize.height)
            .scaleEffect(x: -1, y: 1)
            .offset(x: 6, y: 71)
            .accessibilityHidden(true)
    }

    /// dot 인디케이터 + CTA. CTA 는 마지막 스텝에서만 보이되 **자리는 늘 차지한다** —
    /// 나타날 때 자리를 밀면 스텝을 넘길 때마다 위의 카드가 함께 튄다.
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
    TutorialContent(steps: TutorialStep.all, pageIndex: $pageIndex)
}

#Preview("마지막 스텝") {
    @Previewable @State var pageIndex = TutorialStep.all.count - 1
    TutorialContent(steps: TutorialStep.all, pageIndex: $pageIndex)
}
