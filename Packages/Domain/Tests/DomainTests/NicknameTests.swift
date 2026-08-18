import Testing
@testable import Domain

@Suite("Nickname — 닉네임 입력 규칙")
struct NicknameTests {
    @Test("트림 후 최소 길이를 넘으면 생성된다")
    func createsWhenLongEnough() throws {
        let nickname = try #require(Nickname("민호"))
        #expect(nickname.value == "민호")
    }

    @Test("앞뒤 공백을 제거한 값을 보존한다")
    func trimsWhitespace() throws {
        let nickname = try #require(Nickname("  민호  "))
        #expect(nickname.value == "민호")
    }

    @Test("공백만 입력하면 만들 수 없다")
    func rejectsWhitespaceOnly() {
        #expect(Nickname("   ") == nil)
    }

    @Test("트림 후 1자면 만들 수 없다")
    func rejectsSingleCharacter() {
        #expect(Nickname(" 민 ") == nil)
    }

    @Test("빈 문자열은 만들 수 없다")
    func rejectsEmpty() {
        #expect(Nickname("") == nil)
    }
}
