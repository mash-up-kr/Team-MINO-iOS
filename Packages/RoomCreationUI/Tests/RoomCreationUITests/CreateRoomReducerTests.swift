import MVITestSupport
import Testing
@testable import RoomCreationUI

@MainActor
struct CreateRoomReducerTests {
    @Test("L1 — roomNameChanged: 입력값이 반영되고 공백만 입력하면 생성 버튼이 비활성 상태다")
    func roomNameChanged_updatesStateAndCreateEnabled() async {
        let store = TestStore(CreateRoomState(), reduce: createRoomReducer())

        await store.send(.roomNameChanged("   ")) {
            $0.roomName = "   "
        }
        #expect(!store.currentState.isCreateEnabled)

        await store.send(.roomNameChanged("민호야 잘하자")) {
            $0.roomName = "민호야 잘하자"
        }
        #expect(store.currentState.isCreateEnabled)

        store.finish()
    }

    @Test("L1 — roomNameChanged: 공백 포함 15자를 넘으면 잘린다")
    func roomNameChanged_truncatesAt15Characters() async {
        let store = TestStore(CreateRoomState(), reduce: createRoomReducer())
        let overLimit = "가나다라마바사아자차카타파하거너"  // 16자
        let truncated = String(overLimit.prefix(15))

        await store.send(.roomNameChanged(overLimit)) {
            $0.roomName = truncated
        }

        store.finish()
    }

    @Test("L1 — roomDescriptionChanged: 입력값이 반영되고 20자를 넘으면 잘린다")
    func roomDescriptionChanged_updatesStateAndTruncatesAt20Characters() async {
        let store = TestStore(CreateRoomState(), reduce: createRoomReducer())

        await store.send(.roomDescriptionChanged("팀 회식 장소 모음")) {
            $0.roomDescription = "팀 회식 장소 모음"
        }

        let overLimit = String(repeating: "가", count: 25)
        let truncated = String(overLimit.prefix(20))
        await store.send(.roomDescriptionChanged(overLimit)) {
            $0.roomDescription = truncated
        }

        store.finish()
    }

    @Test("L1 — selectColor: 선택한 색 인덱스가 State 에 반영된다")
    func selectColor_updatesState() async {
        let store = TestStore(CreateRoomState(), reduce: createRoomReducer())

        await store.send(.selectColor(3)) {
            $0.selectedColorIndex = 3
        }

        store.finish()
    }

    @Test("L2 — tapNext(방 생성하기): goToInviteFriends 로 navigate 한다")
    func tapNext_navigatesToInviteFriends() async {
        let store = TestStore(CreateRoomState(), reduce: createRoomReducer())

        await store.send(.tapNext)
        store.receiveNavigation(.goToInviteFriends)

        store.finish()
    }

    @Test("L1 — tapSkip(건너뛰기): 목적지가 기획에 없어 navigate 하지 않는다")
    func tapSkip_doesNotNavigate() async {
        let store = TestStore(CreateRoomState(), reduce: createRoomReducer())

        await store.send(.tapSkip)

        store.finish()   // 미수신 nav 가 있으면 여기서 실패한다
    }
}
