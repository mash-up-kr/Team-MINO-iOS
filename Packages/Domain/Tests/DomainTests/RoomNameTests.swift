import Testing
@testable import Domain

@Suite("RoomName — 방 이름 입력 규칙")
struct RoomNameTests {
    @Test("clampedDraft 는 최대 길이를 넘는 입력을 자른다")
    func clampsDraft() {
        let draft = String(repeating: "가", count: 16)
        #expect(RoomName.clampedDraft(draft) == String(repeating: "가", count: 15))
    }

    @Test("clampedDraft 는 빈 draft 를 그대로 통과시킨다 — 타이핑 중간 상태")
    func keepsEmptyDraft() {
        #expect(RoomName.clampedDraft("") == "")
    }

    @Test("공백만으로는 만들 수 없다")
    func rejectsWhitespaceOnly() {
        #expect(RoomName("   ") == nil)
    }

    @Test("경계 15자는 그대로 생성된다")
    func acceptsBoundaryLength() throws {
        let fifteen = String(repeating: "가", count: 15)
        let name = try #require(RoomName(fifteen))
        #expect(name.value == fifteen)
    }

    @Test("트림 후 클램프한 값을 보존한다")
    func trimsThenClamps() throws {
        let name = try #require(RoomName("  우리 동네 맛집  "))
        #expect(name.value == "우리 동네 맛집")
    }
}
