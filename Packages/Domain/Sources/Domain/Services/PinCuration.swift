import Foundation

/// 핀 큐레이션 정책 — 방 상세의 "꾹 Pick"·"최신순" 규칙.
/// 어느 한 Pin 의 자연스러운 책임이 아니라 컬렉션 위에서 성립하는 규칙이라 도메인 서비스로 둔다.
/// 화면의 정렬 선택지(전체·거리순·코멘트순 포함)와 dispatch 는 Feature 가 담당한다.
public enum PinCuration: Sendable {
    private static let topRatio = 0.3
    private static let recentDays = 14.0
    private static let secondsPerDay = 86_400.0

    /// 꾹 Pick: createdAt 오름차순(오래된 순) 상위 round(0.3 × n)건, 비어있지 않으면 최소 1건.
    public static func pick(from pins: [Pin]) -> [Pin] {
        Array(pins.sorted { $0.createdAt < $1.createdAt }.prefix(topCount(of: pins.count)))
    }

    /// 최신순: now 로부터 14일 이내만(경계 포함), createdAt 내림차순.
    /// 주의: "14일"은 절대초(86,400×14) 기준이라 `Pin.savedDays` 의 달력일 계산과 기준이 다르다 —
    /// 기존 동작 보존을 위해 의도적으로 통일하지 않았다.
    public static func latest(from pins: [Pin], now: Date) -> [Pin] {
        let cutoff = now.addingTimeInterval(-recentDays * secondsPerDay)
        return pins.filter { $0.createdAt >= cutoff }.sorted { $0.createdAt > $1.createdAt }
    }

    private static func topCount(of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return max(1, Int((Double(total) * topRatio).rounded()))
    }
}
