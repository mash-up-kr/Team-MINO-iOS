import Domain
import Foundation

/// 정렬 드롭다운 값별 목록 규칙. Figma `1672:66212` — "카드 정렬 값 = 모든 값은 그룹 내의 순위로 정렬"
/// (값이 그룹을 먼저 거르고, 그 그룹 안에서 정렬한다).
///
/// **거리순·코멘트순은 계산할 수 없다** — `Domain.Pin` 에 좌표도 코멘트 수도 없다.
/// 시안대로 항목은 두되 목록은 원본 순서를 그대로 둔다.
enum RoomDetailSorting {
    /// 스펙의 "상위 30프로".
    private static let topRatio = 0.3
    /// 최신순이 노출하는 기간(스펙 "현재일 기준 최근 14일 이내").
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

        // TODO: Pin 에 좌표(거리순)·코멘트 수(코멘트순)가 생기면 구현한다.
        case .distance, .comment:
            return pins
        }
    }

    /// 비어 있지 않은 목록은 최소 1건을 남긴다 — 반올림으로 통째로 비면 정렬이 아니라 고장으로 보인다.
    private static func topCount(of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return max(1, Int((Double(total) * topRatio).rounded()))
    }
}
