import DesignSystem
import SwiftUI

/// 튜토리얼 화면. 게시물 위로 시트 두 개가 차례로 오르내린다.
///
/// 딤과 시트를 여기서 각각 그리는 이유는 전환이 달라서다 — 시트는 아래에서 올라오고(`move`),
/// 딤은 페이드한다(`opacity`). 두 시트가 교대할 때 딤은 그대로 유지돼 깜빡이지 않는다.
///
/// 아직 flow 에 붙지 않아 Coordinator 대신 `makeStore` 를 받는다. 붙일 때 Coordinator 의
/// `makeTutorialStore` 를 넘기면 된다(`RoomCreationUI.CreateRoomView` 와 같은 모양).
struct TutorialView: View {
    let makeStore: () -> TutorialStore

    @State private var store: TutorialStore?

    var body: some View {
        if let store {
            content(store)
        } else {
            // 마크업이 자체 상단 내비를 그려 로딩 표시가 자리를 밀지 않도록 빈 배경으로 자리만 잡는다.
            Color.mhBackgroundNormalNormal
                .ignoresSafeArea()
                .task { store = makeStore() }
        }
    }

    private func content(_ store: TutorialStore) -> some View {
        ZStack(alignment: .bottom) {
            TutorialShareGuideContent(
                onTapSkip: { store.send(.tapSkip) },
                onTapShare: { store.send(.tapShare) }
            )
            .disabled(store.state.step != .shareGuide)

            if store.state.step != .shareGuide {
                Color.mhMaterialDimmer
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            if store.state.step == .shareTarget {
                TutorialShareTargetContent(onTapShareTarget: { store.send(.tapShareTarget) })
                    .transition(.move(edge: .bottom))
                    .accessibilityAddTraits(.isModal)
            }

            if store.state.step == .systemShareSheet {
                // 시트의 X 는 넘기지 않는다 — 튜토리얼 중에는 닫히지 않는다(기본값 = 무동작).
                TutorialSystemShareSheetContent(onTapAppShare: { store.send(.tapAppShare) })
                    .transition(.move(edge: .bottom))
                    .accessibilityAddTraits(.isModal)
            }
        }
        // reduce 는 순수해야 해서 withAnimation 을 넣을 수 없다 — 단계 변화를 뷰가 애니메이션한다.
        .animation(.easeInOut(duration: 0.3), value: store.state.step)
    }
}

#Preview {
    TutorialView(makeStore: { TutorialStore(TutorialState(), reduce: tutorialReducer()) })
}
