import Domain
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
/// // 마이페이지 — 진입하면서 조회해 채운다. 뒤로가기는 onBack 을 넘겨야 그려진다.
/// ProfileSetupScreen(
///     makeStore: {
///         let store = makeProfileSetupStore(.edit(fetch: deps.fetchProfile, update: deps.updateProfile))
///         store.observeNavigation { [weak self] in self?.handle($0) }   // 필수
///         return store
///     },
///     onBack: { dismiss() }
/// )
/// ```
public struct ProfileSetupScreen: View {
    private let makeStore: @MainActor () -> ProfileSetupStore
    private let onBack: (() -> Void)?
    @State private var store: ProfileSetupStore?

    /// - Parameters:
    ///   - makeStore: Store 생성. 진입 목적은 `makeProfileSetupStore(_:)` 에 넘기는 deps 가 정하고,
    ///     `edit` 의 초기값은 진입 후 조회로 채워진다.
    ///   - onBack: 뒤로가기 동작. **넘기지 않으면 뒤로가기를 그리지 않는다** — 온보딩 최초 진입처럼
    ///     돌아갈 곳이 없는 화면을 위해. 띄운 쪽이 아는 사실이라 화면이 판단하지 않는다.
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
                onBack: onBack,
                saveErrorMessage: store.state.saveError.map(Self.saveErrorMessage)
            )
            // 안내는 잠깐 띄웠다 거둔다(저장 탭과 같은 자리라 계속 두면 버튼을 가린다).
            // id 를 걸어 새 실패가 오면 타이머가 다시 시작된다.
            .task(id: store.state.saveError) {
                guard store.state.saveError != nil else { return }
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                store.send(.dismissSaveError)
            }
        }
    }

    /// 저장 실패를 사용자 문구로 옮긴다.
    ///
    /// `DomainError` 의 extension 으로 두지 않는다 — 화면 전용 문구가 공용 타입의 public 표면에
    /// 영구히 붙고, 다음 화면이 같은 방식으로 각자 붙이면 "세션 만료" 같은 공통 문구가 갈라진다.
    /// 두 번째 화면이 같은 문구를 필요로 할 때 공용 자리로 올린다.
    private static func saveErrorMessage(_ error: DomainError) -> String {
        switch error {
        case .unauthorized, .sessionUnavailable:
            "로그인이 만료됐어요. 앱을 다시 열어주세요."
        default:
            "저장하지 못했어요. 잠시 후 다시 시도해주세요."
        }
    }
}
