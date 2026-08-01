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

    @Test("L2 — tapNext 는 goToCreateRoom 으로 navigate 한다")
    func tapNext_navigatesToCreateRoom() async {
        let store = TestStore(ProfileSetupState(), reduce: profileSetupReducer())

        await store.send(.tapNext)
        store.receiveNavigation(.goToCreateRoom)

        store.finish()
    }
}
