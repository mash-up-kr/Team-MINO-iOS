import MapUI

/// 클러스터를 눌러 낸 확대 요청. 좌표와 목표 줌을 함께 든다 — 둘을 따로 들면 한쪽만 갱신된
/// 상태가 생긴다.
///
/// `Equatable` 이라 `@State` 갱신이 같은 값에서 헛돌지 않는다.
struct ArchiveZoomRequest: Equatable {
    let coordinate: MapCoordinate
    let zoom: Float
}
