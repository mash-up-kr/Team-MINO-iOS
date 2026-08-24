import Domain
import Foundation

enum RoomDetailSorting {
    private static let topRatio = 0.3

    static func apply(_ sort: RoomDetailSort, to pins: [Pin], now: Date) -> [Pin] {
        switch sort {
        case .all:
            return pins

        case .pick:
            return Array(pins.sorted { $0.createdAt < $1.createdAt }.prefix(topCount(of: pins.count)))

        case .latest:
            // 재정렬만 한다. 기간 컷오프를 걸면 목록에서 장소가 사라지는데, 라벨이 그냥 "최신순"이라
            // 사용자에게 축소가 예고되지 않는다. 기간 필터는 카테고리 칩 소관이다.
            return pins.sorted { $0.createdAt > $1.createdAt }

        case .distance, .comment:
            return pins
        }
    }

    private static func topCount(of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return max(1, Int((Double(total) * topRatio).rounded()))
    }
}
