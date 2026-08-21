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
        // 방 색(hex) 이 피커 인덱스로 옮겨진다 — sample 은 Cyan(6번째 칸).
        #expect(store.state.selectedColorIndex == RoomColorPalette.index(ofHex: RoomDetailRoom.sample.color))
        #expect(store.state.selectedColorIndex == 5)
    }

    // 팔레트 밖 색이면 칸을 켜지 않는다 — 잘못된 칸을 켜는 것보다 미선택이 낫다.
    @Test("팔레트에 없는 방 색이면 색이 선택되지 않은 채 열린다")
    func makeRoomFormStore_withUnknownColor_leavesSelectionEmpty() {
        let coordinator = ProfileCoordinator()
        coordinator.startRoomEdit(
            RoomDetailRoom(title: "방", memo: "", color: "#123456", locationCountText: "0개", memberCount: 1)
        )

        #expect(coordinator.makeRoomFormStore().state.selectedColorIndex == nil)
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
