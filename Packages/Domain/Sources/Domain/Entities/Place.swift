import Foundation

/// 지도상의 장소 — 이름·주소·좌표를 가진 도메인 Entity.
///
/// `Pin` aggregate **안에** 산다. 고유 id 를 갖지만 aggregate root 가 아니다:
/// 서버에 장소 단독 조회 경로가 없고(`GET /places/{id}` 없음) 클라이언트는 이 값을 고치지 않는다.
/// Evans — "Provide repositories only for aggregate roots that actually need direct access."
/// 그래서 ID 참조가 아니라 `Pin` 에 임베드한다.
///
/// 프레임워크에 의존하지 않는 순수 value type 이며 Codable 을 준수하지 않는다(API 스키마와 결합 방지).
public struct Place: Equatable, Identifiable, Sendable {
    public let id: PlaceID
    public let name: String
    public let address: String
    public let coordinate: Coordinate
    /// 업종(카페·음식점 등). 서버가 provider 별 정규화 규칙을 확정하기 전이라 **값 집합이 미정**이므로
    /// 타입으로 닫지 않고 원문을 통과시킨다. 확정되면 그때 VO 로 올린다.
    ///
    /// 주의: `PinCategory` 와 다른 개념이다 — 그쪽은 홈 카드 뱃지용 큐레이션 라벨이다.
    public let category: String?
    /// 외부 지도 서비스의 장소 상세 URL(서버가 준 것). 앱이 조립하는 애플지도 URL 과 별개다.
    public let mapURL: URL?

    public init(
        id: PlaceID,
        name: String,
        address: String,
        coordinate: Coordinate,
        category: String? = nil,
        mapURL: URL? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.category = category
        self.mapURL = mapURL
    }
}
