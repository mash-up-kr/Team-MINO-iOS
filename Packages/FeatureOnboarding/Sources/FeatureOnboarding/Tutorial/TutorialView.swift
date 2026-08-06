import DesignSystem
import SwiftUI

/// 튜토리얼이 어디까지 진행됐는지. 시트가 오르내리는 한 화면이라 단계를 상태로 든다.
enum TutorialStep: Equatable {
    /// 게시물의 공유 버튼을 눌러보게 하는 단계.
    case shareGuide
    /// 공유 대상 시트가 올라온 단계.
    case shareTarget
    /// 시스템 공유시트가 올라온 단계.
    case systemShareSheet
}

/// 튜토리얼 화면. 게시물 위로 시트 두 개가 차례로 오르내린다.
///
/// 단계를 상태로 들고 흐름을 제어하므로 `Content`(순수 마크업)가 아니라 `View` 다.
///
/// 딤과 시트를 여기서 각각 그리는 이유는 전환이 달라서다 — 시트는 아래에서 올라오고(`move`),
/// 딤은 페이드한다(`opacity`). 두 시트가 교대할 때 딤은 그대로 유지돼 깜빡이지 않는다.
///
/// > 단계 전환을 지금은 `@State` 로 들고 있다. Store 가 붙으면 이 `step` 이 State 로,
/// > 각 콜백이 Action 으로 옮겨간다(`.claude/docs/mvi-coordinator-di.md` 5절).
struct TutorialView: View {
    /// 마지막 단계(시스템 공유시트)에서 우리 앱을 골랐을 때. 완료 화면으로 가는 건 flow 몫이라 밖으로 넘긴다.
    var onFinish: () -> Void = {}
    var onTapSkip: () -> Void = {}

    @State private var step: TutorialStep = .shareGuide

    var body: some View {
        ZStack(alignment: .bottom) {
            TutorialShareGuideContent(
                onTapSkip: onTapSkip,
                onTapShare: { go(to: .shareTarget) }
            )
            // 시트가 떠 있는 동안 뒤 화면은 잠근다. 직접 그린 오버레이라 `.sheet` 처럼
            // 시스템이 막아주지 않아, 스크린리더가 딤 뒤의 건너뛰기·공유 버튼까지 훑을 수 있다.
            .disabled(step != .shareGuide)
            .accessibilityHidden(step != .shareGuide)

            if step != .shareGuide {
                Color.mhMaterialDimmer
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            if step == .shareTarget {
                TutorialShareTargetContent(onTapShareTarget: { go(to: .systemShareSheet) })
                    .transition(.move(edge: .bottom))
            }

            if step == .systemShareSheet {
                // 시트의 X 는 넘기지 않는다 — 튜토리얼 중에는 닫히지 않는다(기본값 = 무동작).
                TutorialSystemShareSheetContent(onTapAppShare: onFinish)
                    .transition(.move(edge: .bottom))
            }
        }
    }

    private func go(to next: TutorialStep) {
        withAnimation(.easeInOut(duration: 0.3)) { step = next }
    }
}

#Preview {
    TutorialView()
}
