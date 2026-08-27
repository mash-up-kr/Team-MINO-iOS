import Foundation

/// DTO 날짜(ISO8601) 파싱. Swift6 Sendable 한 `ISO8601FormatStyle` 사용(공유 가변 상태 없음).
/// 파싱 불가 시 epoch(0)로 보수적 처리한다.
///
/// DTO 매핑이 여럿 공유한다 — 복제하면 날짜 폴백 정책이 두 곳으로 갈라진다.
func parseISO8601(_ string: String) -> Date {
    (try? Date(string, strategy: .iso8601)) ?? Date(timeIntervalSince1970: 0)
}
