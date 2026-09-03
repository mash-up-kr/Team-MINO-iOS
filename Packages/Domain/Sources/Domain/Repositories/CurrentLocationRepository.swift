import Foundation

/// 기기의 현재 위치를 한 번 읽는 추상 인터페이스.
///
/// 권한 조회·요청은 ``PermissionRepository`` 가 맡는다 — 이쪽은 **이미 허용된 뒤의 측위**만 책임진다.
/// 위치 변화를 계속 흘려보내는 형태(스트림)가 아닌 건, 지금 필요한 것이 "고른 순간에 내가 어디인가"
/// 한 번뿐이기 때문이다(004-1 ⑥ 거리순).
public protocol CurrentLocationRepository: Sendable {
    /// 지금 위치를 한 번 측정한다. 측위에 실패했거나 제때 얻지 못하면 nil.
    func currentCoordinate() async -> Coordinate?
}
