import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — Store 는 .task 에서 1회 lazy 생성
//
// Coordinator 대신 `makeStore` 클로저를 받는다: 이 화면은 온보딩과 방리스트가 함께 쓰므로 특정
// Coordinator 타입을 알면 다른 쪽에서 못 쓴다. 누가 만들었는지 몰라도 1회 생성은 그대로 유지된다.
public struct RoomFormView: View {
    private let makeStore: @MainActor () -> RoomFormStore
    private let showsSkip: Bool
    private let showsBack: Bool
    @State private var store: RoomFormStore?

    /// - Parameters:
    ///   - showsSkip: 상단바 건너뛰기 버튼 노출. 건너뛸 수 없는 진입점(방리스트·편집 등)은 `false`.
    ///     눌렀을 때 어디로 갈지는 `RoomFormNav.didSkip` 을 받는 소비자가 정한다.
    ///   - showsBack: 상단바 뒤로가기 노출. 온보딩은 돌아갈 곳이 없어 `false`(디자인 ⑦).
    public init(
        makeStore: @escaping @MainActor () -> RoomFormStore,
        showsSkip: Bool = true,
        showsBack: Bool = true
    ) {
        self.makeStore = makeStore
        self.showsSkip = showsSkip
        self.showsBack = showsBack
    }

    public var body: some View {
        Group {
            if let store {
                RoomFormContent(
                    state: store.state,
                    send: store.send,
                    showsSkip: showsSkip,
                    showsBack: showsBack
                )
            } else {
                ProgressView()
                    .task { store = makeStore() }
            }
        }
        // 마크업이 자체 상단 내비바를 그린다 — 시스템 내비바를 두면 뒤로가기가 두 개로 보인다.
        .toolbar(.hidden, for: .navigationBar)
    }
}
