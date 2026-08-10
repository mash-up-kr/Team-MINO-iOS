import Core
import Foundation
import MVITestSupport
import Testing
@testable import ShareExtensionUI

@MainActor
struct SaveLinkReducerTests {
    private static let link = SharedLinkPreview(url: URL(string: "https://example.com/place/1")!)
    private static let rooms = [
        SharedRoom(id: "1", name: "내 방", placeCount: 3),
        SharedRoom(id: "2", name: "성수 카페", memo: "주말", placeCount: 5),
    ]

    /// 대기 없는 의존 — 저장·피드백 지연을 즉시 끝내 테스트를 결정적으로 만든다.
    private static func instantDependencies(
        saved: @escaping @Sendable (SharedLinkPreview, Set<String>) -> Void = { _, _ in }
    ) -> SaveLinkDependencies {
        SaveLinkDependencies(save: { saved($0, $1) }, holdCompletion: {})
    }

    private static func makeStore(
        _ dependencies: SaveLinkDependencies = instantDependencies()
    ) -> TestStore<SaveLinkState, SaveLinkAction, SaveLinkNav> {
        TestStore(SaveLinkState(link: link, rooms: rooms), reduce: saveLinkReducer(dependencies))
    }

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

    @Test("L1 — tapSave: 방을 고르지 않았으면 아무 일도 일어나지 않는다")
    func tapSave_withoutSelection_doesNothing() async {
        let store = Self.makeStore()

        await store.send(.tapSave)

        #expect(!store.currentState.isSaving)
        store.finish()
    }

    @Test("L2 — tapSave: 고른 방 목록이 저장으로 넘어가고 완료 후 시트를 닫는다")
    func tapSave_savesSelectedRoomsThenDismisses() async {
        let recorder = SaveRecorder()
        let store = Self.makeStore(Self.instantDependencies { link, ids in
            recorder.record(link: link, ids: ids)
        })

        await store.send(.toggleRoom("2")) { $0.selectedRoomIDs = ["2"] }
        await store.send(.tapSave) { $0.isSaving = true }
        await store.receive(.saveFinished) {
            $0.isSaving = false
            $0.isSaved = true
        }
        await store.receive(.completionShown)
        store.receiveNavigation(.dismiss)

        #expect(recorder.ids == ["2"])
        #expect(recorder.link == Self.link)
        store.finish()
    }

    @Test("L1 — 저장이 시작된 뒤에는 선택을 바꿀 수 없다")
    func toggleRoom_whileSaving_isIgnored() async {
        let store = Self.makeStore(SaveLinkDependencies(save: { _, _ in }, holdCompletion: {}))

        await store.send(.toggleRoom("1")) { $0.selectedRoomIDs = ["1"] }
        await store.send(.tapSave) { $0.isSaving = true }

        // 저장 중(isSaving) 상태에서의 토글 — 아무 변화도 없어야 한다.
        await store.send(.toggleRoom("2"))

        await store.receive(.saveFinished) {
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

    @Test("L1 — tapClose: 저장하지 않고 시트를 닫는다")
    func tapClose_dismissesWithoutSaving() async {
        let store = Self.makeStore()

        await store.send(.tapClose)
        store.receiveNavigation(.dismiss)

        #expect(!store.currentState.isSaved)
        store.finish()
    }
}

/// 저장 클로저가 무엇을 받았는지 기록한다.
private final class SaveRecorder: @unchecked Sendable {
    private(set) var link: SharedLinkPreview?
    private(set) var ids: Set<String>?

    func record(link: SharedLinkPreview, ids: Set<String>) {
        self.link = link
        self.ids = ids
    }
}
