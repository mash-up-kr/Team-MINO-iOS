import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — Store 는 .task 에서 1회 lazy 생성
//
// Coordinator 대신 `makeStore` 클로저를 받는다: 이 화면은 온보딩과 마이페이지가 함께 쓰므로 특정
// Coordinator 타입을 알면 다른 쪽에서 못 쓴다. 누가 만들었는지 몰라도 1회 생성은 그대로 유지된다.
//
// NavigationStack 을 갖지 않는다 — 스택 소유는 소비하는 Feature 몫이라, 온보딩은 flow 루트로
// 띄우고 마이페이지는 자기 스택에 push 할 수 있다.
//
/// 프로필 설정 화면. Figma `010-1/2/3`.
///
/// 진입점마다 **초기값과 저장 동작이 다르다** — 화면은 같고 Store 를 어떻게 만드느냐로 가른다.
///
/// ```swift
/// // 온보딩 — 빈 값에서 시작, 돌아갈 곳이 없어 뒤로가기 없음. 저장은 유저 등록.
/// ProfileSetupScreen(makeStore: coordinator.makeProfileSetupStore)
///
/// // 마이페이지 — 조회한 프로필로 프리필한다. 뒤로가기는 mode 가 알아서 그린다.
/// ProfileSetupScreen(makeStore: {
///     let store = ProfileSetupStore(
///         ProfileSetupState(mode: .edit, name: profile.name, selectedCharacterIndex: profile.characterIndex),
///         reduce: profileSetupReducer()
///     )
///     store.observeNavigation { [weak self] in self?.handle($0) }   // 필수
///     return store
/// })
/// ```
///
/// > 저장 API 는 아직 안 붙어 있다 — `profileSetupReducer` 주석 참조.
public struct ProfileSetupScreen: View {
    private let makeStore: @MainActor () -> ProfileSetupStore
    private let onBack: (() -> Void)?
    @State private var store: ProfileSetupStore?

    /// - Parameters:
    ///   - makeStore: Store 생성. 진입 목적과 초기값을 `ProfileSetupState(mode:name:selectedCharacterIndex:)`
    ///     로 정한다 — 뒤로가기 노출도 `mode` 에서 파생되므로 따로 넘기지 않는다.
    ///   - onBack: 뒤로가기 동작. 생략하면 `dismiss` 환경값으로 pop 한다.
    public init(
        makeStore: @escaping @MainActor () -> ProfileSetupStore,
        onBack: (() -> Void)? = nil
    ) {
        self.makeStore = makeStore
        self.onBack = onBack
    }

    public var body: some View {
        Group {
            if let store {
                content(store)
            } else {
                ProgressView()
                    .task { store = makeStore() }
            }
        }
        // 마크업이 자체 상단 내비바를 그린다 — 시스템 내비바를 두면 뒤로가기가 두 개로 보인다.
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func content(_ store: ProfileSetupStore) -> some View {
        ProfileSetupContent(
            name: Binding(
                get: { store.state.name },
                set: { store.send(.nameChanged($0)) }
            ),
            selectedCharacterIndex: store.state.selectedCharacterIndex,
            showsNameError: store.state.shouldShowNameError,
            isSaveEnabled: store.state.isSaveEnabled,
            isClearEnabled: store.state.isClearEnabled,
            onSelectCharacter: { store.send(.selectCharacter($0)) },
            onClear: { store.send(.tapClear) },
            onSave: { store.send(.tapSave) },
            onBack: store.state.mode.showsBack ? (onBack ?? { dismiss() }) : nil
        )
    }

    @Environment(\.dismiss) private var dismiss
}
