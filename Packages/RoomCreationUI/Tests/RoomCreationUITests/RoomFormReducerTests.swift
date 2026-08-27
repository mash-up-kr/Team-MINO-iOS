import Domain
import MVITestSupport
import Testing
@testable import RoomCreationUI

@MainActor
struct RoomFormReducerTests {
    @Test("L1 — roomNameChanged: 입력값이 반영되고 공백만 입력하면 생성 버튼이 비활성 상태다")
    func roomNameChanged_updatesStateAndCreateEnabled() async {
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: StubCreateRoomUseCase())))

        await store.send(.roomNameChanged("   ")) {
            $0.roomName = "   "
        }
        #expect(!store.currentState.isSubmitEnabled)

        await store.send(.roomNameChanged("민호야 잘하자")) {
            $0.roomName = "민호야 잘하자"
        }
        #expect(store.currentState.isSubmitEnabled)

        store.finish()
    }

    // 자르지 않고 그대로 담아야 `count > limit` 이 성립해 워닝이 뜬다 — 잘라 담던 시절엔
    // 초과 상태에 도달할 수가 없어 에러 UI 가 영원히 안 떴다(이슈 #93).
    @Test("L1 — roomNameChanged: 15자 경계 — 넘겨도 자르지 않고 담되 무효 처리한다")
    func roomNameChanged_keepsOverLimitInputAndInvalidates() async {
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: StubCreateRoomUseCase())))
        let atLimit = "가나다라마바사아자차카타파하거"      // 15자
        let overLimit = atLimit + "너"                     // 16자

        await store.send(.roomNameChanged(atLimit)) { $0.roomName = atLimit }
        #expect(store.currentState.isNameValid)
        #expect(store.currentState.isSubmitEnabled)

        await store.send(.roomNameChanged(overLimit)) { $0.roomName = overLimit }
        #expect(!store.currentState.isNameValid)
        #expect(!store.currentState.isSubmitEnabled)

        store.finish()
    }

    @Test("L1 — roomNameChanged: 한글·영문·숫자·공백 밖의 문자는 무효다")
    func roomNameChanged_rejectsDisallowedCharacters() async {
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: StubCreateRoomUseCase())))

        await store.send(.roomNameChanged("Mino 4팀 room")) { $0.roomName = "Mino 4팀 room" }
        #expect(store.currentState.isNameValid)

        await store.send(.roomNameChanged("민호야 잘하자^^")) { $0.roomName = "민호야 잘하자^^" }
        #expect(!store.currentState.isNameValid)
        #expect(!store.currentState.isSubmitEnabled)

        store.finish()
    }

    // 이걸 막으면 한글을 치는 내내 에러 테두리가 깜빡인다 — 자모는 조합이 끝나기 전 잠깐 state 로 들어온다.
    @Test("L1 — roomNameChanged: 한글 조합 중간 상태(자모)는 유효하다")
    func roomNameChanged_allowsHangulJamoDuringComposition() async {
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: StubCreateRoomUseCase())))

        await store.send(.roomNameChanged("ㅁ")) { $0.roomName = "ㅁ" }
        #expect(store.currentState.isNameValid)

        await store.send(.roomNameChanged("미ㄴ")) { $0.roomName = "미ㄴ" }
        #expect(store.currentState.isNameValid)

        store.finish()
    }

    @Test("L1 — roomDescriptionChanged: 30자 경계 — 넘겨도 자르지 않고 담되 생성을 막는다")
    func roomDescriptionChanged_keepsOverLimitInputAndBlocksCreate() async {
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: StubCreateRoomUseCase())))
        let atLimit = String(repeating: "가", count: 30)
        let overLimit = String(repeating: "가", count: 31)

        await store.send(.roomNameChanged("민호야 잘하자")) { $0.roomName = "민호야 잘하자" }

        await store.send(.roomDescriptionChanged(atLimit)) { $0.roomDescription = atLimit }
        #expect(store.currentState.isDescriptionValid)
        #expect(store.currentState.isSubmitEnabled)

        await store.send(.roomDescriptionChanged(overLimit)) { $0.roomDescription = overLimit }
        #expect(!store.currentState.isDescriptionValid)
        #expect(!store.currentState.isSubmitEnabled)

        store.finish()
    }

    @Test("L1 — selectColor: 선택한 색 인덱스가 State 에 반영된다")
    func selectColor_updatesState() async {
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: StubCreateRoomUseCase())))

        await store.send(.selectColor(3)) {
            $0.selectedColorIndex = 3
        }

        store.finish()
    }

    // Nav 는 목적지가 아니라 일어난 일을 알린다 — 어디로 갈지는 소비하는 flow 가 정하므로
    // 이 테스트는 "무엇이 일어났는지"만 단언한다.
    @Test("L2 — tapSubmit(방 생성하기): 곧장 전환하지 않고 저장 확인 다이얼로그를 띄운다")
    func tapCreate_whenCreateEnabled_showsSaveDialog() async {
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: StubCreateRoomUseCase())))

        await store.send(.roomNameChanged("민호야 잘하자")) {
            $0.roomName = "민호야 잘하자"
        }

        await store.send(.tapSubmit) { $0.dialog = .saveConfirm }
        await store.send(.confirmSubmit) {
            $0.dialog = nil
            $0.isSaving = true
        }
        await store.receive(.saveSucceeded) { $0.isSaving = false }
        store.receiveNavigation(.didSubmit)

        store.finish()
    }

    @Test("L2 — tapBack(뒤로가기): 취소 확인 다이얼로그를 거쳐야 didCancel 이 나간다")
    func tapBack_showsCancelDialogThenNotifiesDidCancel() async {
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: StubCreateRoomUseCase())))

        await store.send(.tapBack) { $0.dialog = .cancelConfirm }
        await store.send(.confirmCancel) { $0.dialog = nil }
        store.receiveNavigation(.didCancel)

        store.finish()
    }

    @Test("L2 — dismissDialog: 다이얼로그만 닫고 화면은 그대로다")
    func dismissDialog_closesWithoutNavigating() async {
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: StubCreateRoomUseCase())))

        await store.send(.roomNameChanged("민호야 잘하자")) { $0.roomName = "민호야 잘하자" }
        await store.send(.tapSubmit) { $0.dialog = .saveConfirm }
        await store.send(.dismissDialog) { $0.dialog = nil }

        // finish 가 미수신 navigation 잔여를 검사한다 — 취소했는데 전환이 나갔다면 여기서 실패한다
        store.finish()
    }

    @Test("L2 — tapSubmit: 생성 조건 미충족이면 아무것도 알리지 않는다 — 뷰의 .disabled 와 별개로 reduce 가 막는다")
    func tapCreate_whenCreateDisabled_notifiesNothing() async {
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: StubCreateRoomUseCase())))

        await store.send(.tapSubmit)

        await store.send(.roomNameChanged("   ")) {
            $0.roomName = "   "
        }
        await store.send(.tapSubmit)

        // finish 가 미수신 navigation 잔여를 검사한다 — didSubmit 이 나갔다면 여기서 실패한다
        store.finish()
    }

    @Test("L2 — tapSubmit: 색·설명을 채워도 이름이 오류면 막힌다 (디자인 ⑤)")
    func tapCreate_whenNameInvalid_notifiesNothingEvenWithOtherFields() async {
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: StubCreateRoomUseCase())))

        await store.send(.roomNameChanged("민호야 잘하자^^")) { $0.roomName = "민호야 잘하자^^" }
        await store.send(.roomDescriptionChanged("팀 회식 장소 모음")) { $0.roomDescription = "팀 회식 장소 모음" }
        await store.send(.selectColor(1)) { $0.selectedColorIndex = 1 }

        await store.send(.tapSubmit)

        store.finish()
    }

    // MARK: 편집 모드

    @Test("L1 — 편집 모드: 기존 방 값으로 열리고 곧바로 확정할 수 있다")
    func editMode_opensPrefilled() {
        // 편집 초기값은 makeRoomFormStore 가 채운다 — 호출부가 State 를 직접 조립하면 여기서 어긋난다.
        let store = makeRoomFormStore(
            .edit(
                room: .stub(name: "야호", description: "야호호", color: .lightBlue),
                update: StubUpdateRoomUseCase()
            ),
            handle: { _ in }
        )

        #expect(store.state.mode == .edit)
        #expect(store.state.roomName == "야호")
        #expect(store.state.roomDescription == "야호호")
        #expect(store.state.selectedColorIndex == RoomColorPalette.index(of: .lightBlue))
        #expect(store.state.isSubmitEnabled)
    }

    @Test("L1 — 편집 모드: 서버가 팔레트에 없는 색을 줘도 열리고, 색만 미선택으로 시작한다")
    func editMode_withUnknownColor_opensWithNoSelection() {
        let store = makeRoomFormStore(
            .edit(room: .stub(color: nil), update: StubUpdateRoomUseCase()),
            handle: { _ in }
        )

        #expect(store.state.selectedColorIndex == nil)
        #expect(store.state.isSubmitEnabled)
    }

    // 편집 화면(004-5-3)에는 확인 모달 시안이 없다 — 생성 모드와 갈리는 지점이라 고정해 둔다.
    @Test("L2 — 편집 모드 tapSubmit: 확인 다이얼로그 없이 didSubmit 을 알린다")
    func editMode_tapSubmit_notifiesWithoutDialog() async {
        let store = TestStore(
            RoomFormState(mode: .edit, roomName: "야호"),
            reduce: roomFormReducer(.edit(room: .stub(), update: StubUpdateRoomUseCase()))
        )

        await store.send(.tapSubmit) { $0.isSaving = true }
        await store.receive(.saveSucceeded) { $0.isSaving = false }
        store.receiveNavigation(.didSubmit)

        store.finish()
    }

    // 나가기는 편집에서도 묻는다(변경 유실 경고). 문구만 화면이 mode 로 갈아 끼운다.
    @Test("L2 — 편집 모드 tapBack: 생성 모드와 똑같이 취소 확인 다이얼로그를 거친다")
    func editMode_tapBack_showsCancelDialog() async {
        let store = TestStore(
            RoomFormState(mode: .edit, roomName: "야호"),
            reduce: roomFormReducer(.edit(room: .stub(), update: StubUpdateRoomUseCase()))
        )

        await store.send(.tapBack) { $0.dialog = .cancelConfirm }
        await store.send(.confirmCancel) { $0.dialog = nil }
        store.receiveNavigation(.didCancel)

        store.finish()
    }

    @Test("L2 — 편집 모드: 이름이 오류면 생성 모드와 똑같이 막힌다")
    func editMode_whenNameInvalid_notifiesNothing() async {
        let store = TestStore(
            RoomFormState(mode: .edit, roomName: "야호"),
            reduce: roomFormReducer(.edit(room: .stub(), update: StubUpdateRoomUseCase()))
        )

        await store.send(.roomNameChanged("야호^^")) { $0.roomName = "야호^^" }
        await store.send(.tapSubmit)

        store.finish()
    }

    @Test("L2 — tapSkip(건너뛰기): didSkip 을 알린다")
    func tapSkip_notifiesDidSkip() async {
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: StubCreateRoomUseCase())))

        await store.send(.tapSkip)
        store.receiveNavigation(.didSkip)

        store.finish()
    }
}
