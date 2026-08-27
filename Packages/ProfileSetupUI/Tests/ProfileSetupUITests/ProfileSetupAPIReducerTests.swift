import Domain
import MVITestSupport
import Testing
@testable import ProfileSetupUI

/// 진입 목적에 따라 어떤 API 를 타는지 — 화면이 등록과 수정을 헷갈리면 사용자 데이터가 뒤집힌다.
@MainActor
struct ProfileSetupAPIReducerTests {
    @Test("L2 — create 진입은 조회하지 않는다 — 온보딩엔 불러올 프로필이 없다")
    func createMode_doesNotFetch() async {
        let store = TestStore(
            ProfileSetupState(mode: .create),
            reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase()))
        )

        await store.send(.task)   // 아무 effect 도 나가지 않아야 한다

        #expect(!store.currentState.isLoading)
        store.finish()
    }

    @Test("L2 — edit 진입은 조회해서 이름·캐릭터를 채운다")
    func editMode_fetchesAndPrefills() async {
        let profile = StubProfile.make(nickname: "민호", avatarColor: .pink)
        let store = TestStore(
            ProfileSetupState(mode: .edit),
            reduce: profileSetupReducer(
                .edit(fetch: StubFetchProfileUseCase(.success(profile)), update: StubUpdateProfileUseCase())
            )
        )

        #expect(store.currentState.isLoading, "조회가 끝나기 전엔 로딩이다")

        await store.send(.task)
        await store.receive(.loaded(profile)) {
            $0.isLoading = false
            $0.name = "민호"
            $0.selectedCharacterIndex = 7
        }

        #expect(store.currentState.isSaveEnabled)
        store.finish()
    }

    @Test("L2 — 조회 실패는 로딩을 끝내고 에러를 남긴다")
    func editMode_fetchFailure() async {
        let store = TestStore(
            ProfileSetupState(mode: .edit),
            reduce: profileSetupReducer(
                .edit(
                    fetch: StubFetchProfileUseCase(.failure(.profileFetchFailed)),
                    update: StubUpdateProfileUseCase()
                )
            )
        )

        await store.send(.task)
        await store.receive(.loadFailed(.profileFetchFailed)) {
            $0.isLoading = false
            $0.loadError = .profileFetchFailed
        }

        store.finish()
    }

    @Test("L2 — create 저장은 등록 API 를 타고 트림된 이름·아바타를 보낸다")
    func createMode_saveCallsRegister() async {
        let register = StubRegisterProfileUseCase()
        let store = TestStore(ProfileSetupState(mode: .create), reduce: profileSetupReducer(.create(register: register)))

        await store.send(.nameChanged("  민호  ")) { $0.name = "  민호  " }
        await store.send(.selectCharacter(3)) { $0.selectedCharacterIndex = 3 }
        await store.send(.tapSave) { $0.isSaving = true }
        await store.receive(.saveSucceeded) { $0.isSaving = false }
        store.receiveNavigation(.didSave)

        #expect(register.received?.nickname == "민호", "앞뒤 공백은 빼고 보낸다")
        #expect(register.received?.avatarColor == .green)
        store.finish()
    }

    @Test("L2 — edit 저장은 수정 API 를 탄다")
    func editMode_saveCallsUpdate() async {
        let update = StubUpdateProfileUseCase()
        let store = TestStore(
            ProfileSetupState(mode: .edit),
            reduce: profileSetupReducer(.edit(fetch: StubFetchProfileUseCase(), update: update))
        )

        await store.send(.nameChanged("민호")) { $0.name = "민호" }
        await store.send(.tapSave) { $0.isSaving = true }
        await store.receive(.saveSucceeded) { $0.isSaving = false }
        store.receiveNavigation(.didSave)

        #expect(update.received?.nickname == "민호")
        store.finish()
    }

    @Test("L2 — 캐릭터를 안 골랐으면 첫 캐릭터로 저장한다 — 화면이 보여준 것과 같은 값")
    func save_withoutSelection_usesFirstCharacter() async {
        let register = StubRegisterProfileUseCase()
        let store = TestStore(ProfileSetupState(mode: .create), reduce: profileSetupReducer(.create(register: register)))

        await store.send(.nameChanged("민호")) { $0.name = "민호" }
        await store.send(.tapSave) { $0.isSaving = true }
        await store.receive(.saveSucceeded) { $0.isSaving = false }
        store.receiveNavigation(.didSave)

        #expect(register.received?.avatarColor == .red)
        store.finish()
    }

    @Test("L2 — 저장 실패는 navigate 하지 않고 에러를 남긴다")
    func save_failure_doesNotNavigate() async {
        let store = TestStore(
            ProfileSetupState(mode: .create),
            reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase(error: .profileSaveFailed)))
        )

        await store.send(.nameChanged("민호")) { $0.name = "민호" }
        await store.send(.tapSave) { $0.isSaving = true }
        await store.receive(.saveFailed(.profileSaveFailed)) {
            $0.isSaving = false
            $0.saveError = .profileSaveFailed
        }

        // finish 가 미수신 navigation 잔여를 검사한다 — didSave 가 나갔다면 여기서 실패한다
        store.finish()
    }

    // 재설치 등으로 이미 등록된 uid 가 다시 등록을 시도한 경우. 오류로 막으면 다시 눌러도
    // 같은 409 라 온보딩을 벗어날 방법이 없다 — 계정은 이미 있으므로 성공으로 흡수한다.
    @Test("L2 — 등록에서 이미 등록된 계정이면 실패가 아니라 다음 단계로 보낸다")
    func save_alreadyRegistered_treatedAsSuccess() async {
        let store = TestStore(
            ProfileSetupState(mode: .create),
            reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase(error: .alreadyRegistered)))
        )

        await store.send(.nameChanged("민호")) { $0.name = "민호" }
        await store.send(.tapSave) { $0.isSaving = true }
        await store.receive(.saveFailed(.alreadyRegistered)) { $0.isSaving = false }
        store.receiveNavigation(.didSave)

        #expect(store.currentState.saveError == nil)   // 오류 안내를 띄우지 않는다
        store.finish()
    }

    // 흡수는 **등록 전용**이다. 반부패 계층이 엔드포인트를 구분하지 않고 409 를 전부
    // alreadyRegistered 로 번역하므로, 모드를 보지 않으면 수정 실패가 조용히 성공이 된다 —
    // 사용자는 저장되지 않은 값을 저장됐다고 보게 된다.
    @Test("L2 — 수정에서 받은 409 는 흡수하지 않고 실패로 남긴다")
    func edit_alreadyRegistered_isNotAbsorbed() async {
        let store = TestStore(
            ProfileSetupState(mode: .edit),
            reduce: profileSetupReducer(.edit(
                fetch: StubFetchProfileUseCase(),
                update: StubUpdateProfileUseCase(error: .alreadyRegistered)
            ))
        )

        await store.send(.loaded(StubProfile.make(nickname: "민호", avatarColor: .redOrange))) {
            $0.isLoading = false
            $0.name = "민호"
            $0.selectedCharacterIndex = 1
        }
        await store.send(.tapSave) { $0.isSaving = true }
        await store.receive(.saveFailed(.alreadyRegistered)) {
            $0.isSaving = false
            $0.saveError = .alreadyRegistered
        }

        // finish 가 미수신 navigation 잔여를 검사한다 — didSave 가 나갔다면 여기서 실패한다
        store.finish()
    }

    @Test("L1 — 저장 중에는 저장·지우기를 다시 누를 수 없다")
    func whileSaving_buttonsAreDisabled() async {
        var state = ProfileSetupState(mode: .create, name: "민호", selectedCharacterIndex: 1)
        #expect(state.isSaveEnabled)
        #expect(state.isClearEnabled)

        state.isSaving = true

        #expect(!state.isSaveEnabled)
        #expect(!state.isClearEnabled)
    }
}
