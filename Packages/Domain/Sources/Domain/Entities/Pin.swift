import Foundation

public struct Pin: Equatable, Identifiable, Sendable {
    public let id: PinID
    public let roomID: String
    public let category: PinCategory
    public let title: String
    public let address: String
    public let createdAt: Date

    public init(
        id: PinID,
        roomID: String,
        category: PinCategory,
        title: String,
        address: String,
        createdAt: Date
    ) {
        self.id = id
        self.roomID = roomID
        self.category = category
        self.title = title
        self.address = address
        self.createdAt = createdAt
    }

    /// 저장 후 경과 "N일째" — 달력일 기준 1-based (저장 당일 = 1일째, 자정을 넘기면 +1).
    /// 기기 시계가 과거로 가 있어도 1 아래로 내려가지 않는다.
    /// 주의: `PinCuration.latest` 의 최근 판정은 절대초(86,400×14) 기준이라 이 계산과 기준이 다르다 —
    /// 기존 동작 보존을 위해 의도적으로 통일하지 않았다.
    public func savedDays(asOf now: Date, calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: createdAt)
        let to = calendar.startOfDay(for: now)
        let elapsed = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        return max(1, elapsed + 1)
    }
}
