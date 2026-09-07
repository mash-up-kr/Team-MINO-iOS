import Testing
@testable import MapUI

/// 핀 아래 장소명 표기 규칙을 고정한다.
///
/// PRD 「커스텀 핀 마커」 — *"**최대 2줄**까지 노출하며 **한 줄은 7자 기준으로 줄바꿈**한다.
/// 장소명이 **14자를 초과하면 2번째 줄에서 13자 + `...`** 로 말줄임한다."*
///
/// 지도 위 글자는 눈으로 세기 어려워(작고, 이름마다 다르다) 규칙이 어긋나도 알아채기 힘들다.
@Suite("핀 라벨 줄바꿈·말줄임")
struct MarkerLabelTests {
    @Test("7자까지는 한 줄이다")
    func singleLine() {
        #expect(MarkerLabel.lines(for: "레이어스") == ["레이어스"])
        #expect(MarkerLabel.lines(for: "일곱글자입니다") == ["일곱글자입니다"])   // 정확히 7자
    }

    @Test("8자부터 두 줄로 갈린다 — 7자 + 나머지")
    func wrapsAtSeven() {
        #expect(MarkerLabel.lines(for: "여덟글자입니다요") == ["여덟글자입니다", "요"])
    }

    // 14자(7×2)는 두 줄에 꽉 차므로 자르지 않는다. "초과" 가 경계라 14와 15가 갈린다.
    @Test("14자는 두 줄에 꽉 차고 말줄임하지 않는다")
    func exactlyFourteen() {
        let name = "열네글자가정확히여기까지"   // 12자
        #expect(MarkerLabel.lines(for: name).count == 2)

        let fourteen = String(repeating: "가", count: 14)
        #expect(MarkerLabel.lines(for: fourteen) == [
            String(repeating: "가", count: 7),
            String(repeating: "가", count: 7),
        ])
    }

    @Test("14자를 넘으면 2번째 줄이 13자에서 끊기고 말줄임표가 붙는다")
    func truncatesBeyondFourteen() {
        let fifteen = String(repeating: "가", count: 15)

        let lines = MarkerLabel.lines(for: fifteen)

        #expect(lines.count == 2)
        #expect(lines[0] == String(repeating: "가", count: 7))
        // 8~13번째 = 6자 + "..."
        #expect(lines[1] == String(repeating: "가", count: 6) + "...")
    }

    // 아무리 길어도 두 줄을 넘지 않는다 — 마커가 세로로 커지면 지도를 덮는다.
    @Test("아무리 길어도 두 줄이다")
    func neverMoreThanTwoLines() {
        let long = String(repeating: "가", count: 100)
        #expect(MarkerLabel.lines(for: long).count == MarkerLabel.maxLines)
    }

    @Test("이름이 비면 라벨을 그리지 않는다")
    func emptyName() {
        #expect(MarkerLabel.lines(for: "").isEmpty)
    }

    // 글자 수는 `Character` 로 센다 — 이모지·결합 문자를 UTF-16 단위로 세면 7자가 다르게 잘린다.
    @Test("결합 문자도 한 글자로 센다")
    func countsGraphemes() {
        let name = "👨‍👩‍👧‍👦카페"   // 가족 이모지 1자 + 2자 = 3자
        #expect(MarkerLabel.lines(for: name) == [name])
    }
}
