import Domain
import Foundation

enum RoomDetailSorting {
    private static let topRatio = 0.3
    private static let recentDays = 14.0
    private static let secondsPerDay = 86_400.0

    static func apply(_ sort: RoomDetailSort, to pins: [Pin], now: Date) -> [Pin] {
        switch sort {
        case .all:
            return pins

        case .pick:
            return Array(pins.sorted { $0.createdAt < $1.createdAt }.prefix(topCount(of: pins.count)))

        case .latest:
            let cutoff = now.addingTimeInterval(-recentDays * secondsPerDay)
            return pins.filter { $0.createdAt >= cutoff }.sorted { $0.createdAt > $1.createdAt }

        case .distance, .comment:
            return pins
        }
    }

    private static func topCount(of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return max(1, Int((Double(total) * topRatio).rounded()))
    }
}
