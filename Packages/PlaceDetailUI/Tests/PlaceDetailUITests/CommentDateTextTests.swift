import Foundation
import Testing
@testable import PlaceDetailUI

/// `CommentDateText` 경계값 — 기획서(Figma 005 주석10) 규칙: 10일까지 상대 시간, 11일부터 절대 날짜.
/// 날짜 경계는 캘린더 날짜 기준(자정 넘김)이지 24시간 버킷이 아니다 — `crossesMidnight...` 케이스 참조.
struct CommentDateTextTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private func text(_ createdAt: Date, now: Date) -> String {
        CommentDateText.text(for: createdAt, now: now, calendar: calendar)
    }

    @Test("작성 직후는 방금 전")
    func justNow() {
        let now = date(2027, 1, 15, 12, 0, 0)
        #expect(text(now, now: now) == "방금 전")
        #expect(text(now.addingTimeInterval(-30), now: now) == "방금 전")   // 59초 전
    }

    @Test("59분 전")
    func fiftyNineMinutesAgo() {
        let now = date(2027, 1, 15, 12, 0, 0)
        let createdAt = now.addingTimeInterval(-59 * 60)   // 같은 날 11:01
        #expect(text(createdAt, now: now) == "59분 전")
    }

    @Test("같은 날 안에서 23시간 전")
    func twentyThreeHoursAgoSameDay() {
        // 자정을 넘기지 않도록 now 를 하루 끝 쪽에 둔다 — 23시간 차이가 나도 캘린더 날짜는 같다.
        let now = date(2027, 1, 15, 23, 59, 0)
        let createdAt = date(2027, 1, 15, 0, 59, 0)
        #expect(text(createdAt, now: now) == "23시간 전")
    }

    @Test("자정을 넘기면 몇 분 차이여도 1일 전 — 24시간 버킷이 아니라 캘린더 날짜 기준")
    func crossesMidnightIntoOneDayAgo() {
        let createdAt = date(2027, 1, 14, 23, 59, 0)
        let now = date(2027, 1, 15, 0, 1, 0)   // 2분 경과
        #expect(text(createdAt, now: now) == "1일 전")
    }

    @Test("경계값: 10일 전은 마지막 상대 표기")
    func tenDaysAgoIsStillRelative() {
        let now = date(2027, 1, 15, 12, 0, 0)
        let createdAt = calendar.date(byAdding: .day, value: -10, to: now)!
        #expect(text(createdAt, now: now) == "10일 전")
    }

    @Test("경계값: 11일 전부터 절대 날짜로 전환")
    func elevenDaysAgoSwitchesToAbsoluteDate() {
        let now = date(2027, 1, 15, 12, 0, 0)
        let createdAt = calendar.date(byAdding: .day, value: -11, to: now)!   // 2027.01.04
        #expect(text(createdAt, now: now) == "2027.01.04")
    }

    @Test("연 경계를 넘는 상대 표기(12.31 → 01.01)")
    func relativeAcrossYearBoundary() {
        let now = date(2027, 1, 1, 12, 0, 0)
        let createdAt = date(2026, 12, 31, 12, 0, 0)
        #expect(text(createdAt, now: now) == "1일 전")
    }

    @Test("연 경계를 넘는 절대 날짜 표기")
    func absoluteDateAcrossYearBoundary() {
        let now = date(2027, 1, 1, 12, 0, 0)
        let createdAt = calendar.date(byAdding: .day, value: -11, to: now)!   // 2026.12.21
        #expect(text(createdAt, now: now) == "2026.12.21")
    }

    @Test("미래(시계 어긋남)는 방금 전으로 흡수")
    func futureCollapsesToJustNow() {
        let now = date(2027, 1, 15, 12, 0, 0)
        let createdAt = now.addingTimeInterval(3600)   // now 보다 1시간 뒤
        #expect(text(createdAt, now: now) == "방금 전")
    }

    @Test("기기 캘린더가 비그레고리력이어도 절대 날짜는 그레고리력 연도로 고정된다")
    func absoluteDateStaysGregorianEvenWithNonGregorianCalendar() {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = TimeZone(identifier: "Asia/Seoul")!

        let now = date(2027, 1, 1, 12, 0, 0)
        let createdAt = calendar.date(byAdding: .day, value: -11, to: now)!   // 2026.12.21

        // 불교력으로 계산해도(일 수·자정 경계는 caller 캘린더를 그대로 쓴다) 표기는
        // 불교력 연도(2569)가 아니라 그레고리력 연도로 고정돼야 한다.
        #expect(CommentDateText.text(for: createdAt, now: now, calendar: buddhist) == "2026.12.21")
    }
}
