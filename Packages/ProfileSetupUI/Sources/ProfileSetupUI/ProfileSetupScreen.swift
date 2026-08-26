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
/// // 온보딩 — 빈 값에서 시작, 뒤로가기 없음. 저장은 유저 등록.
/// ProfileSetupScreen(makeStore: coordinator.makeProfileSetupStore)
///
/// // 마이페이지 — 진입하면서 조회해 채운다. 뒤로가기는 mode 가 알아서 그린다.
/// ProfileSetupScreen(makeStore: {
///     let store = makeProfileSetupStore(.edit(fetch: deps.fetchProfile, update: deps.updateProfile))
///     store.observeNavigation { [weak self] in self?.handle($0) }   // 필수
///     return store
/// })
/// ```
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
                    // 진입 로드는 Store 생성과 분리한다(문서 5절). 로딩 분기 **바깥**에 둬야
                    // edit 진입(첫 프레임부터 isLoading)에서도 조회가 시작된다.
                    .task { store.send(.task) }
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
        // edit 진입은 조회가 끝나야 보여줄 게 생긴다 — 그 전엔 빈 폼이 잠깐 스치지 않게 로딩을 둔다.
        if store.state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
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
    }

    @Environment(\.dismiss) private var dismiss
}
