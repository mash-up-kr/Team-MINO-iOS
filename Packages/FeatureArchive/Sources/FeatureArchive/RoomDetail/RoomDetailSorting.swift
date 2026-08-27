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

        case .comment:
            // 시안 004-1 ⑥ — "코멘트 댓글 수 기반 상위 30프로 게시물 노출".
            // 같은 수끼리는 최신 저장이 앞이다(수만으로는 순서가 정해지지 않아 매 조회마다 뒤집힌다).
            return Array(
                pins
                    .sorted { ($0.commentCount, $0.createdAt) > ($1.commentCount, $1.createdAt) }
                    .prefix(topCount(of: pins.count))
            )

        case .distance:
            // 내 위치가 있어야 잴 수 있다(3km 반경). 위치 권한이 붙기 전까지는 원본 순서.
            return pins
        }
    }

    private static func topCount(of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return max(1, Int((Double(total) * topRatio).rounded()))
    }
}
