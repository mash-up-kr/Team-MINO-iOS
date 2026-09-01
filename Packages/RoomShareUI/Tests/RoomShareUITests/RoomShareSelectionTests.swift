import Testing
import RoomShareUI

/// 공유 시트의 방 선택 규칙. View 밖 순수 타입이라 결정적으로 검증한다.
struct RoomShareSelectionTests {
    @Test("아무 방도 고르지 않으면 공유할 수 없다")
    func emptySelectionCannotSubmit() {
        #expect(RoomShareSelection().canSubmit == false)
    }

    @Test("한 방을 고르면 공유할 수 있다")
    func singleSelectionCanSubmit() {
        var selection = RoomShareSelection()
        selection.toggle("room-0")

        #expect(selection.contains("room-0"))
        #expect(selection.canSubmit)
    }

    @Test("여러 방을 동시에 고를 수 있다")
    func multipleSelectionAccumulates() {
        var selection = RoomShareSelection()
        selection.toggle("room-0")
        selection.toggle("room-1")

        #expect(selection.ids == ["room-0", "room-1"])
    }

    @Test("고른 방을 다시 누르면 선택이 풀린다")
    func toggleTurnsSelectionOff() {
        var selection = RoomShareSelection()
        selection.toggle("room-0")
        selection.toggle("room-0")

        #expect(selection.ids.isEmpty)
        #expect(selection.canSubmit == false)
    }
}
