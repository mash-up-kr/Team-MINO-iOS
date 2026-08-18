import Foundation
import Testing
@testable import Domain

@Suite("Pin.savedDays — 저장 경과일 계산")
struct PinSavedDaysTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ iso: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: iso)!
    }

    private func pin(createdAt: Date) -> Pin {
        Pin(
            id: PinID("pin-1"),
            roomID: RoomID("room-1"),
            category: .worthVisiting,
            title: "레이어스튜디오 10",
            address: "서울 성동구 상원4길 10",
            createdAt: createdAt
        )
    }

    @Test("저장한 당일은 1일째")
    func sameDay() {
        let days = pin(createdAt: date("2026-08-16 09:00"))
            .savedDays(asOf: date("2026-08-16 23:00"), calendar: calendar)
        #expect(days == 1)
    }

    @Test("자정을 넘기면 24시간이 안 지나도 2일째")
    func nextCalendarDay() {
        let days = pin(createdAt: date("2026-08-15 23:00"))
            .savedDays(asOf: date("2026-08-16 01:00"), calendar: calendar)
        #expect(days == 2)
    }

    @Test("29일 전 저장이면 30일째")
    func thirtiethDay() {
        let days = pin(createdAt: date("2026-07-18 12:00"))
            .savedDays(asOf: date("2026-08-16 12:00"), calendar: calendar)
        #expect(days == 30)
    }

    @Test("기기 시계가 뒤로 가 있어도 1일째 아래로는 내려가지 않는다")
    func futureDateClamps() {
        let days = pin(createdAt: date("2026-08-20 12:00"))
            .savedDays(asOf: date("2026-08-16 12:00"), calendar: calendar)
        #expect(days == 1)
    }
}
