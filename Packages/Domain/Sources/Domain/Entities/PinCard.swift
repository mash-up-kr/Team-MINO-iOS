import Foundation

/// 홈 카드 덱의 한 장 — 서버가 골라 준 핀에 큐레이션 라벨(뱃지)이 함께 온다.
///
/// `Pin.category: PinCategory?` 로 합치지 않는다. 그러면 nil 이 "목록 응답이라 안 실렸다"와
/// "라벨이 없는 핀이다" 두 뜻을 갖게 되고, 기본값으로 채우면 "서버가 `가볼 만한 곳` 이라 했다" 와
/// 구분이 안 된다. 라벨이 실리는 응답은 홈 카드 하나뿐이므로 `PinDetail` 과 같은 기준으로 나눈다.
public struct PinCard: Equatable, Identifiable, Sendable {
    public let pin: Pin
    /// 홈 카드 뱃지용 큐레이션 라벨. 홈 카드로 장소 상세에 들어갈 때만 상단 라벨로 이어진다.
    public let category: PinCategory

    public var id: PinID { pin.id }

    public init(pin: Pin, category: PinCategory) {
        self.pin = pin
        self.category = category
    }
}
