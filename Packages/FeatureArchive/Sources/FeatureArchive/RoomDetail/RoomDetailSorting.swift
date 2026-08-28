import Domain
import Foundation

enum RoomDetailSorting {
    private static let topRatio = 0.3

    /// - Parameter origin: 거리순의 기준점(내 위치). 다른 정렬은 쓰지 않는다.
    static func apply(
        _ sort: RoomDetailSort,
        to pins: [Pin],
        now: Date,
        from origin: Coordinate? = nil
    ) -> [Pin] {
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
            // 시안 004-1 ⑥ — "거리순 - 내 기준 3km반경 내에 있는 게시물 노출".
            // 반경과 거리 계산은 비즈니스 규칙이라 `Domain.NearbyPins` 가 갖는다.
            //
            // 기준점이 없으면 원본 그대로다. reduce 는 좌표를 얻은 뒤에만 `sort` 를 `.distance` 로
            // 세우므로 실제로는 여기 닿지 않는다 — 전체 함수로 남겨 두기 위한 갈래다.
            guard let origin else { return pins }
            return NearbyPins.sortedByDistance(pins, from: origin)
        }
    }

    private static func topCount(of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return max(1, Int((Double(total) * topRatio).rounded()))
    }
}
