import Foundation

/// 핀 큐레이션 정책 — 방 상세의 "꾹 Pick"·"최신순" 규칙.
/// 어느 한 Pin 의 자연스러운 책임이 아니라 컬렉션 위에서 성립하는 규칙이라 도메인 서비스로 둔다.
/// 화면의 정렬 선택지(전체·거리순·코멘트순 포함)와 dispatch 는 Feature 가 담당한다.
public enum PinCuration: Sendable {
    private static let topRatio = 0.3

    /// 꾹 Pick: createdAt 오름차순(오래된 순) 상위 round(0.3 × n)건, 비어있지 않으면 최소 1건.
    public static func pick(from pins: [Pin]) -> [Pin] {
        Array(pins.sorted { $0.createdAt < $1.createdAt }.prefix(topCount(of: pins.count)))
    }

    /// 최신순: createdAt 내림차순 재정렬. 기간으로 걸러내지 않는다 —
    /// 스펙(TS-004)이 재정렬만 요구하며, 14일 필터는 오래 저장한 장소를 목록에서 지우는 버그였다.
    public static func latest(from pins: [Pin]) -> [Pin] {
        pins.sorted { $0.createdAt > $1.createdAt }
    }

    private static func topCount(of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return max(1, Int((Double(total) * topRatio).rounded()))
    }
}
