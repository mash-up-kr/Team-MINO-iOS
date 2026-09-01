import Foundation

/// 홈 카드 덱의 조회 기준(필터 칩). **선언 순서가 곧 칩 순서이자 기본 순회 순서**다.
///
/// 이 순서를 어떻게 도는지는 여기서 정하지 않는다 — 고른 칩을 앞으로 돌릴지, 한 방을 다 본 뒤
/// 다음 방으로 넘어갈지가 "어떻게 그 자리에 왔는가"(스와이프 vs 방 지목)에 달려 있어 화면 이력이
/// 필요하기 때문이다. 그건 홈 화면이 정하고, 여기는 순서만 든다.
public enum PinFilter: String, CaseIterable, Equatable, Hashable, Sendable {
    /// 꾹 Pick (기본)
    case recommended
    /// 최신순
    case latest
    /// 가까운순
    case nearby
}
