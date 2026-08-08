import MVITestSupport
import Testing
@testable import FeatureOnboarding

@MainActor
struct ProfileSetupReducerTests {
    @Test("L1 — nameChanged 는 State 에 이름을 반영하고 저장을 활성화한다")
    func nameChanged_updatesNameAndEnablesSave() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer())

        await store.send(.nameChanged("민호")) {
            $0.name = "민호"
        }

        #expect(store.currentState.isSaveEnabled)
        store.finish()
    }

    @Test("L1 — 공백만 입력하면 저장이 비활성 상태로 유지된다")
    func nameChanged_whitespaceOnly_keepsSaveDisabled() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer())

        await store.send(.nameChanged("   ")) {
            $0.name = "   "
        }

        #expect(!store.currentState.isSaveEnabled)
        store.finish()
    }

    @Test("L1 — 최소 길이(2자) 미만이면 저장이 비활성이다 — 화면 안내 문구와 같은 기준")
    func nameChanged_shorterThanMinimum_keepsSaveDisabled() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer())

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
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer())

        await store.send(.nameChanged("민")) {
            $0.name = "민"
        }

        #expect(!store.currentState.isSaveEnabled)
        #expect(store.currentState.isClearEnabled)
        store.finish()
    }

    @Test("L1 — 이름이 비면 지우기도 비활성이다")
    func emptyName_disablesClear() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer())

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
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer())

        await store.send(.selectCharacter(5)) {
            $0.selectedCharacterIndex = 5
        }

        store.finish()
    }

    @Test("L1 — tapClear 는 이름만 비우고 캐릭터 선택은 유지한다")
    func tapClear_clearsNameOnly_keepsCharacterSelection() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer())

        await store.send(.nameChanged("민호")) {
            $0.name = "민호"
        }
        await store.send(.selectCharacter(3)) {
            $0.selectedCharacterIndex = 3
        }
        await store.send(.tapClear) {
            $0.name = ""
        }

        #expect(store.currentState.selectedCharacterIndex == 3)
        store.finish()
    }

    @Test("L2 — 저장 가능한 이름이면 tapSave 가 goToCreateRoom 으로 navigate 한다")
    func tapSave_whenSaveEnabled_navigatesToCreateRoom() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer())

        await store.send(.nameChanged("민호")) {
            $0.name = "민호"
        }

        await store.send(.tapSave)
        store.receiveNavigation(.goToCreateRoom)

        store.finish()
    }

    @Test("L2 — 저장 조건 미충족이면 tapSave 가 navigate 하지 않는다 — 뷰의 .disabled 와 별개로 reduce 가 막는다")
    func tapSave_whenSaveDisabled_doesNotNavigate() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer())

        await store.send(.tapSave)

        await store.send(.nameChanged("민")) {
            $0.name = "민"
        }
        await store.send(.tapSave)

        // finish 가 미수신 navigation 잔여를 검사한다 — navigate 가 나갔다면 여기서 실패한다
        store.finish()
    }
}
