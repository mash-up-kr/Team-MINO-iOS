import Foundation

/// 홈 카드 덱의 조회 기준(필터 칩). 순서가 곧 화면의 칩 순서다.
/// 정책: 한 기준의 카드를 모두 넘기면 다음 기준으로 자동 전환하고, 마지막 기준까지 소진하면 소진 화면을 띄운다.
public enum PinFilter: String, CaseIterable, Equatable, Hashable, Sendable {
    /// 꾹 Pick (기본)
    case recommended
    /// 최신순
    case latest
    /// 가까운순
    case nearby

    /// 다음 기준. 마지막(`nearby`)이면 nil — 더 넘길 기준이 없다는 뜻.
    public var next: PinFilter? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index + 1 < all.count else { return nil }
        return all[index + 1]
    }

    /// 이전 기준. 첫 기준(`recommended`)이면 nil — 첫 카드에서 뒤로 가도 더 돌아갈 곳이 없다.
    public var previous: PinFilter? {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self), index > 0 else { return nil }
        return all[index - 1]
    }
}
