import Domain
import MVITestSupport
import Testing
@testable import RoomCreationUI

/// 폼이 실제로 서버에 무엇을 보내고, 실패했을 때 화면을 넘기지 않는지 고정한다.
@MainActor
struct RoomFormAPIReducerTests {
    // MARK: 생성

    @Test("L2 — 저장 확인 후 생성 요청이 나가고, 성공해야 didSubmit 이 나간다")
    func confirmSubmit_createsRoomThenNavigates() async {
        let create = StubCreateRoomUseCase()
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: create)))

        await store.send(.roomNameChanged("  민호야 잘하자  ")) { $0.roomName = "  민호야 잘하자  " }
        await store.send(.roomDescriptionChanged("팀 회식 장소 모음")) { $0.roomDescription = "팀 회식 장소 모음" }
        await store.send(.selectColor(2)) { $0.selectedColorIndex = 2 }

        await store.send(.tapSubmit) { $0.dialog = .saveConfirm }
        await store.send(.confirmSubmit) {
            $0.dialog = nil
            $0.isSaving = true
        }
        await store.receive(.saveSucceeded(roomId: "room-1")) { $0.isSaving = false }
        store.receiveNavigation(.didSubmit(roomId: "room-1"))

        // 앞뒤 공백은 떼고 보낸다.
        #expect(create.received?.name == "민호야 잘하자")
        #expect(create.received?.description == "팀 회식 장소 모음")
        #expect(create.received?.color == RoomColorPalette.color(at: 2))

        store.finish()
    }

    // 뒤따르는 친구 초대 화면이 이 id 로 초대 링크를 발급한다 — 응답을 버리면 그 경로가 막힌다.
    @Test("L2 — 생성 응답의 방 id 가 didSubmit 까지 실려 나간다")
    func createdRoomIdReachesNavigation() async {
        let create = StubCreateRoomUseCase()
        create.result = .stub(id: "server-generated-id")
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: create)))

        await store.send(.roomNameChanged("민호야 잘하자")) { $0.roomName = "민호야 잘하자" }
        await store.send(.tapSubmit) { $0.dialog = .saveConfirm }
        await store.send(.confirmSubmit) {
            $0.dialog = nil
            $0.isSaving = true
        }
        await store.receive(.saveSucceeded(roomId: "server-generated-id")) { $0.isSaving = false }
        store.receiveNavigation(.didSubmit(roomId: "server-generated-id"))

        store.finish()
    }

    @Test("L2 — 설명이 비어 있으면 null 로 보낸다 (서버가 nullable 로 받는다)")
    func confirmSubmit_sendsNilForBlankDescription() async {
        let create = StubCreateRoomUseCase()
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: create)))

        await store.send(.roomNameChanged("민호야 잘하자")) { $0.roomName = "민호야 잘하자" }
        await store.send(.roomDescriptionChanged("   ")) { $0.roomDescription = "   " }
        await store.send(.tapSubmit) { $0.dialog = .saveConfirm }
        await store.send(.confirmSubmit) {
            $0.dialog = nil
            $0.isSaving = true
        }
        await store.receive(.saveSucceeded(roomId: "room-1")) { $0.isSaving = false }
        store.receiveNavigation(.didSubmit(roomId: "room-1"))

        #expect(create.received?.description == nil)

        store.finish()
    }

    // 서버는 color 를 필수로 요구하는데 폼은 색 없이도 확정된다 — 팔레트 첫 색으로 떨어진다.
    @Test("L2 — 색을 안 골라도 요청은 나간다 — 팔레트 첫 색으로 보낸다")
    func confirmSubmit_withoutColor_fallsBackToFirstPaletteColor() async {
        let create = StubCreateRoomUseCase()
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: create)))

        await store.send(.roomNameChanged("민호야 잘하자")) { $0.roomName = "민호야 잘하자" }
        await store.send(.tapSubmit) { $0.dialog = .saveConfirm }
        await store.send(.confirmSubmit) {
            $0.dialog = nil
            $0.isSaving = true
        }
        await store.receive(.saveSucceeded(roomId: "room-1")) { $0.isSaving = false }
        store.receiveNavigation(.didSubmit(roomId: "room-1"))

        #expect(create.received?.color == RoomColorPalette.color(at: 0))

        store.finish()
    }

    // MARK: 실패

    @Test("L2 — 저장이 실패하면 화면을 넘기지 않고 안내만 남긴다")
    func saveFailure_keepsScreenAndShowsError() async {
        let create = StubCreateRoomUseCase()
        create.error = DomainError.roomSaveFailed
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: create)))

        await store.send(.roomNameChanged("민호야 잘하자")) { $0.roomName = "민호야 잘하자" }
        await store.send(.tapSubmit) { $0.dialog = .saveConfirm }
        await store.send(.confirmSubmit) {
            $0.dialog = nil
            $0.isSaving = true
        }
        await store.receive(.saveFailed(.roomSaveFailed)) {
            $0.isSaving = false
            $0.saveError = .roomSaveFailed
        }

        // 입력은 그대로 남아 다시 누르면 재시도가 된다.
        #expect(store.currentState.roomName == "민호야 잘하자")
        #expect(store.currentState.isSubmitEnabled)

        await store.send(.dismissSaveError) { $0.saveError = nil }

        // finish 가 미수신 navigation 잔여를 검사한다 — 실패인데 didSubmit 이 나갔다면 여기서 실패한다
        store.finish()
    }

    @Test("L2 — 도메인 오류가 아닌 실패도 저장 실패로 수렴한다")
    func saveFailure_withUnknownError_fallsBackToRoomSaveFailed() async {
        struct Boom: Error {}
        let create = StubCreateRoomUseCase()
        create.error = Boom()
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: create)))

        await store.send(.roomNameChanged("민호야 잘하자")) { $0.roomName = "민호야 잘하자" }
        await store.send(.tapSubmit) { $0.dialog = .saveConfirm }
        await store.send(.confirmSubmit) {
            $0.dialog = nil
            $0.isSaving = true
        }
        await store.receive(.saveFailed(.roomSaveFailed)) {
            $0.isSaving = false
            $0.saveError = .roomSaveFailed
        }

        store.finish()
    }

    // 취소는 결과가 없는 것이지 실패가 아니다 — 화면을 떠나서 생긴 취소에 오류 UI 가 뜨면 안 된다.
    @Test("L2 — 취소는 오류 상태를 만들지 않는다")
    func cancellation_doesNotBecomeError() async {
        let create = StubCreateRoomUseCase()
        create.error = CancellationError()
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: create)))

        await store.send(.roomNameChanged("민호야 잘하자")) { $0.roomName = "민호야 잘하자" }
        await store.send(.tapSubmit) { $0.dialog = .saveConfirm }
        await store.send(.confirmSubmit) {
            $0.dialog = nil
            $0.isSaving = true
        }

        // 응답 action 이 하나도 돌아오지 않는다 — finish 가 미수신 effect·nav 잔여를 검사한다.
        #expect(store.currentState.saveError == nil)

        store.finish()
    }

    // MARK: 중복 전송

    @Test("L2 — 저장 중에는 확정이 다시 먹지 않는다")
    func whileSaving_submitIsBlocked() async {
        let create = StubCreateRoomUseCase()
        create.error = CancellationError()   // 응답을 돌려주지 않아 isSaving 이 유지된다
        let store = TestStore(RoomFormState(), reduce: roomFormReducer(.create(create: create)))

        await store.send(.roomNameChanged("민호야 잘하자")) { $0.roomName = "민호야 잘하자" }
        await store.send(.tapSubmit) { $0.dialog = .saveConfirm }
        await store.send(.confirmSubmit) {
            $0.dialog = nil
            $0.isSaving = true
        }

        #expect(!store.currentState.isSubmitEnabled)
        await store.send(.tapSubmit)   // 다이얼로그가 다시 뜨지 않는다

        store.finish()
    }

    // MARK: 편집

    @Test("L2 — 편집은 확인 없이 곧장 수정 요청을 보내고 대상 방 id 를 함께 넘긴다")
    func editMode_tapSubmit_updatesTargetRoom() async {
        let update = StubUpdateRoomUseCase()
        let deps = RoomFormDeps.edit(room: .stub(id: "room-42"), update: update)
        let store = TestStore(
            RoomFormState(mode: .edit, roomName: "야호", roomDescription: "야호호", selectedColorIndex: 4),
            reduce: roomFormReducer(deps)
        )

        await store.send(.tapSubmit) { $0.isSaving = true }
        // 편집은 수정 응답을 기다리지 않고 자기가 아는 대상 id 를 그대로 나른다.
        await store.receive(.saveSucceeded(roomId: "room-42")) { $0.isSaving = false }
        store.receiveNavigation(.didSubmit(roomId: "room-42"))

        #expect(update.received?.roomId == "room-42")
        #expect(update.received?.name == "야호")
        #expect(update.received?.description == "야호호")
        #expect(update.received?.color == RoomColorPalette.color(at: 4))

        store.finish()
    }

    @Test("L2 — 편집 저장이 실패하면 편집 화면에 남는다")
    func editMode_saveFailure_keepsScreen() async {
        let update = StubUpdateRoomUseCase()
        update.error = DomainError.unauthorized
        let store = TestStore(
            RoomFormState(mode: .edit, roomName: "야호"),
            reduce: roomFormReducer(.edit(room: .stub(), update: update))
        )

        await store.send(.tapSubmit) { $0.isSaving = true }
        await store.receive(.saveFailed(.unauthorized)) {
            $0.isSaving = false
            $0.saveError = .unauthorized
        }

        store.finish()
    }
}
