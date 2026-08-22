import DesignSystem
import SwiftUI

/// 튜토리얼 화면.
///
/// Coordinator 대신 `makeStore` 클로저를 받는다 — 특정 Coordinator 타입을 알지 않아
/// 진입점이 늘거나 이 화면을 `*UI` 로 내릴 때 그대로 쓸 수 있다.
struct TutorialView: View {
    let makeStore: @MainActor () -> TutorialStore

    @State private var store: TutorialStore?

    var body: some View {
        Group {
            if let store {
                TutorialContent(
                    pageIndex: Binding(
                        get: { store.state.pageIndex },
                        set: { store.send(.selectPage($0)) }
                    ),
                    onTapSkip: { store.send(.tapSkip) },
                    onTapStart: { store.send(.tapStart) }
                )
            } else {
                // ProgressView 를 쓰면 자체 상단 내비가 밀린다 — 빈 배경으로 자리만 잡는다.
                Color.mhBackgroundNormalNormal
                    .ignoresSafeArea()
                    .task { store = makeStore() }
            }
        }
        // 마크업이 자체 상단 내비바를 그린다 — 시스템 내비바를 두면 타이틀이 두 개로 보인다.
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    TutorialView(makeStore: { TutorialStore(TutorialState(), reduce: tutorialReducer()) })
}
