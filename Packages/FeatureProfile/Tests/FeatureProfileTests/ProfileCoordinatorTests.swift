import RoomCreationUI
import Testing
@testable import FeatureProfile

@MainActor
struct ProfileCoordinatorTests {
    @Test("생성 직후 내비게이션 스택은 비어 있다")
    func startsWithEmptyPath() {
        #expect(ProfileCoordinator().path.isEmpty)
    }

    @Test("방 편집 진입은 화면을 push 하고 탭바를 감춘다")
    func startRoomEdit_pushesAndHidesTabBar() {
        let coordinator = ProfileCoordinator()

        coordinator.startRoomEdit(.sample)

        #expect(coordinator.path == [.roomEdit])
        #expect(coordinator.isFullBleedContentPresented)
    }

    @Test("편집 화면은 진입한 방의 이름·설명으로 열린다")
    func makeRoomFormStore_prefillsFromRoom() {
        let coordinator = ProfileCoordinator()
        coordinator.startRoomEdit(.sample)

        let store = coordinator.makeRoomFormStore()

        #expect(store.state.mode == .edit)
        #expect(store.state.roomName == RoomDetailRoom.sample.title)
        #expect(store.state.roomDescription == RoomDetailRoom.sample.memo)
    }

    @Test("편집 완료·취소·건너뛰기는 모두 방 상세로 pop 한다")
    func handleRoomFormNav_popsBack() {
        for nav: RoomFormNav in [.didSubmit, .didCancel, .didSkip] {
            let coordinator = ProfileCoordinator()
            coordinator.startRoomEdit(.sample)

            coordinator.handle(nav)

            #expect(coordinator.path.isEmpty)
            #expect(!coordinator.isFullBleedContentPresented)
        }
    }
}
