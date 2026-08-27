import Foundation
import MVITestSupport
import SavePostUI
import Testing
@testable import ShareExtensionUI

/// 픽스처는 파일 스코프에 둔다 — `@MainActor` 격리된 static 은 의존 클로저(Sendable) 안에서 읽을 수 없다.
private let testRooms = [
    SavePostRoom(id: "1", name: "내 방", placeCount: 3, thumbnail: .myRoom),
    SavePostRoom(id: "2", name: "성수 카페", memo: "주말", placeCount: 5, thumbnail: .color(.violet)),
]

@MainActor
struct SaveLinkReducerTests {
    private static let link = SharedLinkPreview(url: URL(string: "https://example.com/place/1")!)
    private static let rooms = testRooms

    private struct LoadFailure: Error {}
    private struct SaveFailure: Error {}

    /// 대기 없는 의존 — 저장·피드백 지연을 즉시 끝내 테스트를 결정적으로 만든다.
    private static func instantDependencies(
        loadRooms: @escaping @Sendable () async throws -> [SavePostRoom] = { rooms },
        saved: @escaping @Sendable @MainActor (URL, Set<String>) -> Void = { _, _ in },
        saveError: (any Error)? = nil
    ) -> SaveLinkDependencies {
        let failure = saveError.map { UncheckedBox($0) }
        return SaveLinkDependencies(
            loadRooms: loadRooms,
            save: { url, ids in
                if let failure { throw failure.value }
                await saved(url, ids)
            },
            holdCompletion: {}
        )
    }

    /// 방 목록을 **이미 받아온** 상태의 스토어. 로딩 자체를 보는 테스트만 `.loading` 에서 시작한다.
    private static func makeStore(
        _ dependencies: SaveLinkDependencies = instantDependencies(),
        savedRoomIDs: Set<String> = []
    ) -> TestStore<SaveLinkState, SaveLinkAction, SaveLinkNav> {
        var state = SaveLinkState(link: link, savedRoomIDs: savedRoomIDs)
        state.rooms = .loaded(rooms)
        return TestStore(state, reduce: saveLinkReducer(dependencies))
    }

    // MARK: 방 목록 적재

    @Test("L2 — task: 방 목록을 불러와 시트에 싣는다")
    func task_loadsRooms() async {
        let store = TestStore(
            SaveLinkState(link: Self.link),
            reduce: saveLinkReducer(Self.instantDependencies())
        )

        await store.send(.task)
        await store.receive(.roomsLoaded(Self.rooms)) { $0.rooms = .loaded(Self.rooms) }

        #expect(store.currentState.loadedRooms.count == 2)
        store.finish()
    }

    @Test("L2 — task: 목록을 못 불러오면 실패 상태로 간다")
    func task_loadFailure() async {
        let store = TestStore(
            SaveLinkState(link: Self.link),
            reduce: saveLinkReducer(Self.instantDependencies(loadRooms: { throw LoadFailure() }))
        )

        await store.send(.task)
        await store.receive(.roomsLoadFailed) { $0.rooms = .failed }

        store.finish()
    }

    // 취소는 결과가 없는 것이지 실패가 아니다 — 실패 화면을 띄우면 안 된다.
    @Test("L2 — task: 취소는 실패로 번지지 않는다")
    func task_cancellationIsNotFailure() async {
        let store = TestStore(
            SaveLinkState(link: Self.link),
            reduce: saveLinkReducer(Self.instantDependencies(loadRooms: { throw CancellationError() }))
        )

        await store.send(.task)

        #expect(store.currentState.rooms == .loading)
        store.finish()
    }

    // View 의 `.task` 는 재부착 때 다시 불릴 수 있다 — 받아온 목록을 로딩으로 되돌리면 시트가 깜빡인다.
    @Test("L1 — task: 이미 목록을 받았으면 다시 불러오지 않는다")
    func task_afterLoaded_isIgnored() async {
        let store = Self.makeStore()

        await store.send(.task)

        #expect(store.currentState.rooms == .loaded(Self.rooms))
        store.finish()
    }

    // MARK: 선택

    @Test("L1 — toggleRoom: 선택이 토글되고 하나라도 고르면 저장이 활성된다")
    func toggleRoom_togglesSelectionAndSubmitAvailability() async {
        let store = Self.makeStore()
        #expect(!store.currentState.canSubmit)

        await store.send(.toggleRoom("1")) { $0.selectedRoomIDs = ["1"] }
        #expect(store.currentState.canSubmit)

        await store.send(.toggleRoom("2")) { $0.selectedRoomIDs = ["1", "2"] }
        await store.send(.toggleRoom("1")) { $0.selectedRoomIDs = ["2"] }
        #expect(store.currentState.canSubmit)

        await store.send(.toggleRoom("2")) { $0.selectedRoomIDs = [] }
        #expect(!store.currentState.canSubmit)

        store.finish()
    }

    @Test("L1 — 이미 저장된 방은 토글되지 않는다")
    func toggleRoom_alreadySaved_isIgnored() async {
        let store = Self.makeStore(savedRoomIDs: ["1"])

        await store.send(.toggleRoom("1"))

        #expect(store.currentState.selectedRoomIDs.isEmpty)
        store.finish()
    }

    @Test("L1 — 이미 저장된 방만 있으면 저장 버튼이 켜지지 않는다")
    func canSubmit_withOnlySavedRooms_isFalse() async {
        let store = Self.makeStore(savedRoomIDs: ["1", "2"])

        #expect(store.currentState.checkedRoomIDs == ["1", "2"])
        #expect(!store.currentState.canSubmit)
        store.finish()
    }

    @Test("L1 — 저장이 시작된 뒤에는 선택을 바꿀 수 없다")
    func toggleRoom_whileSaving_isIgnored() async {
        let store = Self.makeStore()

        await store.send(.toggleRoom("1")) { $0.selectedRoomIDs = ["1"] }
        await store.send(.tapSave) { $0.isSaving = true }

        // 저장 중(isSaving) 상태에서의 토글 — 아무 변화도 없어야 한다.
        // 응답을 아직 receive 하지 않아 State 는 저장 중에 머물러 있다.
        await store.send(.toggleRoom("2"))

        await store.receive(.saveSucceeded) {
            $0.isSaving = false
            $0.isSaved = true
        }
        // 저장이 끝난(isSaved) 뒤의 토글도 막힌다.
        await store.send(.toggleRoom("2"))
        #expect(store.currentState.selectedRoomIDs == ["1"])

        await store.receive(.completionShown)
        store.receiveNavigation(.dismiss)
        store.finish()
    }

    // MARK: 저장

    @Test("L2 — tapSave: 고른 방 목록이 저장으로 넘어가고 완료 후 시트를 닫는다")
    func tapSave_savesSelectedRoomsThenDismisses() async {
        let recorder = SaveRecorder()
        let store = Self.makeStore(Self.instantDependencies(saved: { recorder.record(url: $0, ids: $1) }))

        await store.send(.toggleRoom("2")) { $0.selectedRoomIDs = ["2"] }
        await store.send(.tapSave) { $0.isSaving = true }
        await store.receive(.saveSucceeded) {
            $0.isSaving = false
            $0.isSaved = true
        }
        await store.receive(.completionShown)
        store.receiveNavigation(.dismiss)

        #expect(recorder.url == Self.link.url)
        #expect(recorder.ids == ["2"])
        #expect(recorder.callCount == 1)
        store.finish()
    }

    @Test("L2 — 저장이 실패하면 시트를 닫지 않고 실패만 알린다")
    func tapSave_failure_keepsSheetOpen() async {
        let store = Self.makeStore(Self.instantDependencies(saveError: SaveFailure()))

        await store.send(.toggleRoom("1")) { $0.selectedRoomIDs = ["1"] }
        await store.send(.tapSave) { $0.isSaving = true }
        await store.receive(.saveFailed) {
            $0.isSaving = false
            $0.saveFailed = true
        }

        #expect(!store.currentState.isSaved)
        #expect(store.currentState.canSubmit)   // 다시 누를 수 있어야 한다
        store.finish()
    }

    // 실패 표시를 남겨두면 재시도 중에도 스낵바가 떠 있어 성공/실패를 구분할 수 없다.
    // 실패 표시를 남겨두면 재시도 중에도 스낵바가 떠 있어 성공/실패를 구분할 수 없다.
    @Test("L2 — 다시 저장하면 이전 실패 표시가 지워진다")
    func tapSave_clearsPreviousFailure() async {
        let store = Self.makeStore(Self.instantDependencies(saveError: SaveFailure()))

        await store.send(.toggleRoom("1")) { $0.selectedRoomIDs = ["1"] }
        await store.send(.tapSave) { $0.isSaving = true }
        await store.receive(.saveFailed) {
            $0.isSaving = false
            $0.saveFailed = true
        }

        await store.send(.tapSave) {
            $0.isSaving = true
            $0.saveFailed = false
        }
        await store.receive(.saveFailed) {
            $0.isSaving = false
            $0.saveFailed = true
        }

        store.finish()
    }

    @Test("L2 — tapSave 를 두 번 눌러도 저장은 한 번만 일어난다")
    func tapSave_twice_savesOnce() async {
        let recorder = SaveRecorder()
        let store = Self.makeStore(Self.instantDependencies(saved: { recorder.record(url: $0, ids: $1) }))

        await store.send(.toggleRoom("1")) { $0.selectedRoomIDs = ["1"] }
        await store.send(.tapSave) { $0.isSaving = true }
        await store.send(.tapSave)   // isSaving 이라 canSubmit 이 false
        await store.receive(.saveSucceeded) {
            $0.isSaving = false
            $0.isSaved = true
        }
        await store.receive(.completionShown)
        store.receiveNavigation(.dismiss)

        #expect(recorder.callCount == 1)
        store.finish()
    }

    @Test("L1 — tapSave: 방을 고르지 않았으면 아무 일도 일어나지 않는다")
    func tapSave_withoutSelection_doesNothing() async {
        let store = Self.makeStore()

        await store.send(.tapSave)

        #expect(!store.currentState.isSaving)
        store.finish()
    }

    @Test("L2 — 저장 대상은 새로 고른 방뿐이다 (이미 저장된 방은 다시 보내지 않는다)")
    func tapSave_sendsOnlyNewlySelectedRooms() async {
        let recorder = SaveRecorder()
        let store = Self.makeStore(
            Self.instantDependencies(saved: { recorder.record(url: $0, ids: $1) }),
            savedRoomIDs: ["1"]
        )

        await store.send(.toggleRoom("2")) { $0.selectedRoomIDs = ["2"] }
        await store.send(.tapSave) { $0.isSaving = true }
        await store.receive(.saveSucceeded) {
            $0.isSaving = false
            $0.isSaved = true
        }
        await store.receive(.completionShown)
        store.receiveNavigation(.dismiss)

        #expect(recorder.ids == ["2"])
        store.finish()
    }

    @Test("L1 — 저장을 시작하지 않았는데 응답이 오면 무시한다")
    func saveResponses_withoutSaving_areIgnored() async {
        let store = Self.makeStore()

        await store.send(.saveSucceeded)
        await store.send(.saveFailed)

        #expect(!store.currentState.isSaved)
        #expect(!store.currentState.saveFailed)
        store.finish()
    }

    @Test("L1 — 저장이 끝나지 않았는데 completionShown 이 오면 닫지 않는다")
    func completionShown_withoutSaved_doesNotDismiss() async {
        let store = Self.makeStore()

        await store.send(.completionShown)

        store.finish()   // navigation 잔여가 없어야 통과한다
    }

    // MARK: 닫기

    @Test("L1 — tapClose: 저장하지 않고 시트를 닫는다")
    func tapClose_dismissesWithoutSaving() async {
        let recorder = SaveRecorder()
        let store = Self.makeStore(Self.instantDependencies(saved: { recorder.record(url: $0, ids: $1) }))

        await store.send(.tapClose)
        store.receiveNavigation(.dismiss)

        #expect(recorder.callCount == 0)
        store.finish()
    }

    @Test("L2 — 저장 중에는 시트 밖을 눌러도 닫히지 않는다")
    func tapClose_whileSaving_isIgnored() async {
        let store = Self.makeStore()

        await store.send(.toggleRoom("1")) { $0.selectedRoomIDs = ["1"] }
        await store.send(.tapSave) { $0.isSaving = true }
        await store.send(.tapClose)   // navigation 이 나가면 finish() 에서 걸린다

        await store.receive(.saveSucceeded) {
            $0.isSaving = false
            $0.isSaved = true
        }
        await store.receive(.completionShown)
        store.receiveNavigation(.dismiss)
        store.finish()
    }
}

/// 저장 클로저가 무엇을 몇 번 받았는지 기록한다.
///
/// 횟수를 세는 이유: 마지막 값만 덮어쓰면 저장이 두 번 일어나도 값 단언이 통과해
/// 중복 저장 가드(`canSubmit`)가 검증되지 않는다.
@MainActor
private final class SaveRecorder {
    private(set) var url: URL?
    private(set) var ids: Set<String>?
    private(set) var callCount = 0

    func record(url: URL, ids: Set<String>) {
        self.url = url
        self.ids = ids
        callCount += 1
    }
}

/// `Error` 를 Sendable 클로저 안으로 나르기 위한 상자. 테스트가 던지는 건 값 타입 오류뿐이다.
private struct UncheckedBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
