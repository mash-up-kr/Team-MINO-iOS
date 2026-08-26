import Foundation
import Testing
@testable import Core

struct SnoozeSwitchTests {
    /// 테스트끼리 섞이지 않도록 매번 새 suite 를 쓴다.
    private func makeDefaults() -> UserDefaults {
        let name = "SnoozeSwitchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeSwitch(
        defaults: UserDefaults,
        period: TimeInterval = .days(14),
        now: @escaping @Sendable () -> Date
    ) -> SnoozeSwitch {
        SnoozeSwitch(key: "prompt", period: period, defaults: defaults, now: now)
    }

    @Test("한 번도 미루지 않았으면 미룬 상태가 아니다")
    func initiallyNotSnoozed() {
        let sut = makeSwitch(defaults: makeDefaults()) { self.start }
        #expect(!sut.isSnoozed)
    }

    @Test("미루면 유예 기간 동안 유지되고, 기간이 지나면 저절로 풀린다")
    func snoozeExpiresAfterPeriod() {
        let defaults = makeDefaults()
        nonisolated(unsafe) var clock = start
        let sut = makeSwitch(defaults: defaults) { clock }

        sut.snooze()
        #expect(sut.isSnoozed)

        clock = start.addingTimeInterval(.days(13))
        #expect(sut.isSnoozed)

        // 경계: 정확히 14일이면 만료다(< period).
        clock = start.addingTimeInterval(.days(14))
        #expect(!sut.isSnoozed)
    }

    // 기기 시계를 과거로 돌려 유도 UI 를 되살리는 걸 막는다.
    @Test("시계가 과거로 돌아가도 미룬 상태가 풀리지 않는다")
    func snoozeSurvivesClockGoingBackwards() {
        let defaults = makeDefaults()
        nonisolated(unsafe) var clock = start
        let sut = makeSwitch(defaults: defaults) { clock }

        sut.snooze()
        clock = start.addingTimeInterval(-.days(30))

        #expect(sut.isSnoozed)
    }

    @Test("키가 다르면 서로 영향을 주지 않는다")
    func keysAreIndependent() {
        let defaults = makeDefaults()
        let a = SnoozeSwitch(key: "a", period: .days(14), defaults: defaults) { self.start }
        let b = SnoozeSwitch(key: "b", period: .days(14), defaults: defaults) { self.start }

        a.snooze()

        #expect(a.isSnoozed)
        #expect(!b.isSnoozed)
    }
}
