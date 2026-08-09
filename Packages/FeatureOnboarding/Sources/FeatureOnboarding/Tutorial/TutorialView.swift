import DesignSystem
import SwiftUI

/// 튜토리얼 화면. 게시물 위로 시트 두 개가 차례로 오르내린다.
///
/// 딤과 시트를 여기서 각각 그리는 이유는 전환이 달라서다 — 시트는 아래에서 올라오고(`move`),
/// 딤은 페이드한다(`opacity`). 두 시트가 교대할 때 딤은 그대로 유지돼 깜빡이지 않는다.
///
/// Coordinator 대신 `makeStore` 클로저를 받는다 — 특정 Coordinator 타입을 알지 않아
/// 진입점이 늘거나 이 화면을 `*UI` 로 내릴 때 그대로 쓸 수 있다.
struct TutorialView: View {
    /// 이만큼 아래로 끌면 시트를 내린다. 시스템 시트의 체감과 맞춘 값.
    private static let dismissDragDistance: CGFloat = 100

    let makeStore: @MainActor () -> TutorialStore

    @State private var store: TutorialStore?
    /// 공유대상 시트를 아래로 끄는 중의 이동량. 손을 떼면 자동으로 0 으로 돌아간다.
    @GestureState private var shareTargetDrag: CGFloat = 0

    var body: some View {
        Group {
            if let store {
                content(store)
            } else {
                // 마크업이 자체 상단 내비를 그려 로딩 표시가 자리를 밀지 않도록 빈 배경으로 자리만 잡는다.
                Color.mhBackgroundNormalNormal
                    .ignoresSafeArea()
                    .task { store = makeStore() }
            }
        }
        // 마크업이 자체 상단 내비바를 그린다 — 시스템 내비바를 두면 뒤로가기가 두 개로 보인다.
        .toolbar(.hidden, for: .navigationBar)
    }

    private func content(_ store: TutorialStore) -> some View {
        ZStack(alignment: .bottom) {
            TutorialShareGuideContent(
                onTapSkip: { store.send(.tapSkip) },
                onTapShare: { store.send(.tapShare) }
            )
            .disabled(store.state.step != .shareGuide)

            // 시트가 떠 있는 동안만 딤을 깐다. `!= .shareGuide` 로 두면 완료 단계에도 남아,
            // 완료 화면이 페이드인하는 동안 딤 걸린 앞 단계가 비쳐 보인다.
            if store.state.step == .shareTarget || store.state.step == .systemShareSheet {
                Color.mhMaterialDimmer
                    .ignoresSafeArea()
                    // 시스템 공유시트가 떠 있을 때는 reduce 가 가드해 무시된다.
                    .onTapGesture { store.send(.dismissShareTarget) }
                    .transition(.opacity)
            }

            if store.state.step == .shareTarget {
                TutorialShareTargetContent(onTapShareTarget: { store.send(.tapShareTarget) })
                    // 위로는 끌리지 않게 막는다 — 시트가 원래 자리보다 올라가면 딤이 아래에서 비친다.
                    .offset(y: max(0, shareTargetDrag))
                    .gesture(
                        DragGesture()
                            .updating($shareTargetDrag) { value, drag, _ in
                                drag = value.translation.height
                            }
                            .onEnded { value in
                                if value.translation.height > Self.dismissDragDistance {
                                    store.send(.dismissShareTarget)
                                }
                            }
                    )
                    .transition(.move(edge: .bottom))
                    .accessibilityAddTraits(.isModal)
            }

            // 완료 화면은 시트가 아니라 앞의 단계를 통째로 덮는다.
            if store.state.step == .complete {
                TutorialCompleteContent()
                    .transition(.opacity)
            }
        }
        // reduce 는 순수해야 해서 withAnimation 을 넣을 수 없다 — 단계 변화를 뷰가 애니메이션한다.
        .animation(.easeInOut(duration: 0.3), value: store.state.step)
        // 3단계는 목업이 아니라 실제 시스템 공유시트를 띄운다. 사용자가 시트에서 우리 앱을
        // 한 번 눌러보게 하는 것이 이 단계의 목적이라, 우리가 그린 화면으로는 대체할 수 없다.
        .background {
            TutorialShareSheet(isPresented: store.state.step == .systemShareSheet) { completed in
                store.send(.shareSheetFinished(completed: completed))
            }
        }
    }
}

#Preview {
    TutorialView(makeStore: { TutorialStore(TutorialState(), reduce: tutorialReducer()) })
}
