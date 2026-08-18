import Testing
@testable import Domain

@Suite("CommentBody — 코멘트 본문 입력 규칙")
struct CommentBodyTests {
    @Test("앞뒤 공백을 제거한 값을 보존한다")
    func trimsWhitespace() throws {
        let body = try #require(CommentBody("  좋은 곳이에요  "))
        #expect(body.value == "좋은 곳이에요")
    }

    @Test("공백만 입력하면 만들 수 없다")
    func rejectsWhitespaceOnly() {
        #expect(CommentBody("   \n  ") == nil)
    }

    @Test("최대 길이를 넘으면 잘라서 보존한다")
    func clampsToLimit() throws {
        let body = try #require(CommentBody(String(repeating: "가", count: 250)))
        #expect(body.value.count == CommentBody.maxLength)
    }

    @Test("경계 200자는 그대로 보존한다")
    func acceptsBoundaryLength() throws {
        let twoHundred = String(repeating: "가", count: 200)
        let body = try #require(CommentBody(twoHundred))
        #expect(body.value == twoHundred)
    }
}
