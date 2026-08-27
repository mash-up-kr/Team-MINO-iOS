import Foundation
import Testing
@testable import FeatureNotification

// SC-005 경계값 6개: 59분/60분/23시간59분/24시간/6일23시간/7일.
struct NotificationElapsedTimeTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    // 기기 시간대와 무관하게 결정적으로 만든다 — 리터럴 기대값(11월 7일)도 이 캘린더 기준.
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    @Test("59분 전 — 방금")
    func fiftyNineMinutes() {
        let createdAt = now.addingTimeInterval(-59 * 60)
        #expect(NotificationElapsedTime.text(since: createdAt, now: now) == "방금")
    }

    @Test("60분 전 — 1시간 전")
    func sixtyMinutes() {
        let createdAt = now.addingTimeInterval(-60 * 60)
        #expect(NotificationElapsedTime.text(since: createdAt, now: now) == "1시간 전")
    }

    @Test("23시간 59분 전 — 23시간 전")
    func twentyThreeHoursFiftyNineMinutes() {
        let createdAt = now.addingTimeInterval(-(23 * 3600 + 59 * 60))
        #expect(NotificationElapsedTime.text(since: createdAt, now: now) == "23시간 전")
    }

    @Test("24시간 전 — 1일 전")
    func twentyFourHours() {
        let createdAt = now.addingTimeInterval(-24 * 3600)
        #expect(NotificationElapsedTime.text(since: createdAt, now: now) == "1일 전")
    }

    @Test("6일 23시간 전 — 6일 전")
    func sixDaysTwentyThreeHours() {
        let createdAt = now.addingTimeInterval(-(6 * 86_400 + 23 * 3600))
        #expect(NotificationElapsedTime.text(since: createdAt, now: now) == "6일 전")
    }

    @Test("7일 전 — N월 N일")
    func sevenDays() {
        let createdAt = now.addingTimeInterval(-7 * 86_400)
        #expect(NotificationElapsedTime.text(since: createdAt, now: now, calendar: utcCalendar) == "11월 7일")
    }
}
