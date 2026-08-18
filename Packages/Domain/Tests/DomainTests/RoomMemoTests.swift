import Testing
@testable import Domain

@Suite("RoomMemo — 방 메모 입력 규칙")
struct RoomMemoTests {
    @Test("clampedDraft 는 최대 길이를 넘는 입력을 자른다")
    func clampsDraft() {
        let draft = String(repeating: "가", count: 25)
        #expect(RoomMemo.clampedDraft(draft) == String(repeating: "가", count: 20))
    }

    @Test("빈 메모도 허용한다 — 거부 규칙 없음")
    func allowsEmpty() {
        #expect(RoomMemo("").value == "")
    }

    @Test("경계 20자는 그대로 보존한다")
    func acceptsBoundaryLength() {
        let twenty = String(repeating: "가", count: 20)
        #expect(RoomMemo(twenty).value == twenty)
    }

    @Test("트림하지 않는다 — 기존 입력 동작 보존")
    func doesNotTrim() {
        #expect(RoomMemo(" 메모 ").value == " 메모 ")
    }
}
