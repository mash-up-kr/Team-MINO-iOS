import Domain
import MVITestSupport
import Testing
@testable import ProfileSetupUI

@MainActor
struct ProfileSetupReducerTests {
    @Test("L1 — nameChanged 는 State 에 이름을 반영하고 저장을 활성화한다")
    func nameChanged_updatesNameAndEnablesSave() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase())))

        await store.send(.nameChanged("민호")) {
            $0.name = "민호"
        }

        #expect(store.currentState.isSaveEnabled)
        store.finish()
    }

    @Test("L1 — 공백만 입력하면 저장이 비활성 상태로 유지된다")
    func nameChanged_whitespaceOnly_keepsSaveDisabled() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase())))

        await store.send(.nameChanged("   ")) {
            $0.name = "   "
        }

        #expect(!store.currentState.isSaveEnabled)
        store.finish()
    }

    @Test("L1 — 최소 길이(2자) 미만이면 저장이 비활성이다 — 화면 안내 문구와 같은 기준")
    func nameChanged_shorterThanMinimum_keepsSaveDisabled() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase())))

        await store.send(.nameChanged("민")) {
            $0.name = "민"
        }
        #expect(!store.currentState.isSaveEnabled)

        // 앞뒤 공백은 길이에서 빠진다 — " 민 " 은 1자 취급
        await store.send(.nameChanged(" 민 ")) {
            $0.name = " 민 "
        }
        #expect(!store.currentState.isSaveEnabled)

        store.finish()
    }

    @Test("L1 — 이름 1글자는 저장은 막고 지우기는 연다 — 두 버튼 조건이 갈리는 유일한 구간")
    func nameChanged_singleCharacter_disablesSaveButEnablesClear() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase())))

        await store.send(.nameChanged("민")) {
            $0.name = "민"
        }

        #expect(!store.currentState.isSaveEnabled)
        #expect(store.currentState.isClearEnabled)
        store.finish()
    }

    @Test("L1 — 이름이 비면 지우기도 비활성이다")
    func emptyName_disablesClear() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase())))

        #expect(!store.currentState.isClearEnabled)

        await store.send(.nameChanged("민호")) {
            $0.name = "민호"
        }
        #expect(store.currentState.isClearEnabled)

        await store.send(.tapClear) {
            $0.name = ""
        }
        #expect(!store.currentState.isClearEnabled)

        store.finish()
    }

    @Test("L1 — selectCharacter 는 선택된 캐릭터 인덱스를 State 에 반영한다")
    func selectCharacter_updatesSelectedIndex() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase())))

        await store.send(.selectCharacter(5)) {
            $0.selectedCharacterIndex = 5
        }

        store.finish()
    }

    @Test("L1 — tapClear 는 이름과 캐릭터 선택을 함께 되돌린다 — 스펙 4번 '클릭 시 1, 2 초기화'")
    func tapClear_clearsNameAndCharacterSelection() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase())))

        await store.send(.nameChanged("민호")) {
            $0.name = "민호"
        }
        await store.send(.selectCharacter(3)) {
            $0.selectedCharacterIndex = 3
        }
        await store.send(.tapClear) {
            $0.name = ""
            $0.selectedCharacterIndex = nil
        }

        #expect(!store.currentState.isClearEnabled)
        store.finish()
    }

    @Test("L1 — 이름이 비어도 캐릭터를 골랐으면 지우기가 열린다 — 지울 대상이 둘이다")
    func selectCharacterOnly_enablesClear() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase())))

        #expect(!store.currentState.isClearEnabled)

        await store.send(.selectCharacter(7)) {
            $0.selectedCharacterIndex = 7
        }

        #expect(store.currentState.isClearEnabled)
        #expect(!store.currentState.isSaveEnabled)
        store.finish()
    }

    @Test("L1 — 한글·영문·공백이 아닌 문자가 섞이면 저장이 막히고 에러를 표시한다")
    func nameChanged_disallowedCharacters_blocksSaveAndShowsError() async {
        for invalid in ["민호1", "민호!", "민호😀", "みんほ", "Мино"] {
            let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase())))

            await store.send(.nameChanged(invalid)) {
                $0.name = invalid
            }

            #expect(!store.currentState.isSaveEnabled, "\(invalid) 는 저장이 막혀야 한다")
            #expect(store.currentState.shouldShowNameError, "\(invalid) 는 에러를 표시해야 한다")
            store.finish()
        }
    }

    @Test("L1 — 한글·영문·공백 조합은 저장이 열리고 에러가 없다")
    func nameChanged_allowedCharacters_enablesSave() async {
        for valid in ["민호", "Mino", "mi no", "민 호", "민호 Mino"] {
            let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase())))

            await store.send(.nameChanged(valid)) {
                $0.name = valid
            }

            #expect(store.currentState.isSaveEnabled, "\(valid) 는 저장이 열려야 한다")
            #expect(!store.currentState.shouldShowNameError, "\(valid) 는 에러가 없어야 한다")
            store.finish()
        }
    }

    @Test("L1 — 입력이 비어 있으면 에러를 표시하지 않는다 — 진입 직후 빨간 테두리가 뜨면 안 된다")
    func emptyName_doesNotShowError() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase())))

        #expect(!store.currentState.shouldShowNameError)

        await store.send(.nameChanged("   ")) {
            $0.name = "   "
        }
        #expect(!store.currentState.shouldShowNameError)

        store.finish()
    }

    @Test("L1 — 조합 중간 자모는 허용 문자다 — 한글을 치는 내내 에러가 깜빡이지 않게")
    func nameChanged_hangulJamo_isAllowedCharacter() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase())))

        // 자모 2개는 문자종·길이를 모두 통과한다. 1개면 길이 미달로 저장만 막힌다.
        await store.send(.nameChanged("ㅁㄴ")) {
            $0.name = "ㅁㄴ"
        }
        #expect(store.currentState.isSaveEnabled)
        #expect(!store.currentState.shouldShowNameError)

        store.finish()
    }


    @Test("L2 — 저장 가능한 이름이면 tapSave 가 didSave 를 알린다")
    func tapSave_whenSaveEnabled_notifiesDidSave() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase())))

        await store.send(.nameChanged("민호")) {
            $0.name = "민호"
        }

        await store.send(.tapSave) { $0.isSaving = true }
        await store.receive(.saveSucceeded) { $0.isSaving = false }
        store.receiveNavigation(.didSave)

        store.finish()
    }

    @Test("L2 — 저장 조건 미충족이면 tapSave 가 navigate 하지 않는다 — 뷰의 .disabled 와 별개로 reduce 가 막는다")
    func tapSave_whenSaveDisabled_doesNotNavigate() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase())))

        await store.send(.tapSave)

        await store.send(.nameChanged("민")) {
            $0.name = "민"
        }
        await store.send(.tapSave)

        // finish 가 미수신 navigation 잔여를 검사한다 — navigate 가 나갔다면 여기서 실패한다
        store.finish()
    }

    @Test("L1 — 진입 목적이 뒤로가기 노출을 가른다 — 온보딩은 돌아갈 곳이 없다")
    func mode_determinesBackVisibility() async {
        #expect(!ProfileSetupMode.create.showsBack)
        #expect(ProfileSetupMode.edit.showsBack)
        #expect(!ProfileSetupState().mode.showsBack, "기본값은 온보딩 진입이다")
    }

    @Test("L1 — edit 진입은 조회한 프로필로 프리필한 채 시작한다")
    func editMode_startsPrefilled() async {
        let state = ProfileSetupState(mode: .edit, name: "민호", selectedCharacterIndex: 7)

        #expect(state.name == "민호")
        #expect(state.selectedCharacterIndex == 7)
        // 프리필만으로 이미 저장 가능해야 한다 — 아무것도 안 고쳐도 되돌릴 게 있다.
        #expect(state.isSaveEnabled)
        #expect(state.isClearEnabled)
    }
}
