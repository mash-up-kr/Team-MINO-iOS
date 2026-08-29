import Foundation

/// "내 주변" 판정 — 기준 좌표에서 일정 반경 안에 있는 핀만 골라 가까운 순으로 세운다.
///
/// 핀 여러 건과 기준 좌표를 함께 봐야 하는 규칙이라 특정 Entity·Value Object 한쪽에 얹을 자리가
/// 없다. Evans — "when a significant process or transformation in the domain is not a natural
/// responsibility of an ENTITY or VALUE OBJECT, add an operation to the model as a standalone
/// interface declared as a SERVICE." 그래서 상태 없는 도메인 서비스로 둔다.
public enum NearbyPins: Sendable {
    /// 시안 004-1 ⑥ — "거리순 - 내 기준 3km반경 내에 있는 게시물 노출".
    /// 경계값(정확히 3km)은 "반경 내" 로 본다.
    public static let radiusInMeters: Double = 3_000

    /// 반경 안의 핀만 남겨 가까운 순으로 세운다.
    ///
    /// 거리가 같은 두 장소는 최신 저장이 앞이다 — 거리만으로는 순서가 정해지지 않아
    /// (Swift 의 `sorted` 는 안정 정렬을 보장하지 않는다) 매 조회마다 뒤집힐 수 있다.
    public static func sortedByDistance(_ pins: [Pin], from origin: Coordinate) -> [Pin] {
        var nearby: [Measured] = []
        for pin in pins {
            let distance = origin.distance(to: pin.place.coordinate)
            guard distance <= radiusInMeters else { continue }
            nearby.append(Measured(pin: pin, distance: distance))
        }
        return nearby.sorted(by: Measured.isBefore).map(\.pin)
    }

    /// 거리를 한 번만 재고 정렬까지 들고 가기 위한 짝. 비교마다 다시 재면 같은 값을 n log n 번 계산한다.
    private struct Measured {
        let pin: Pin
        let distance: Double

        static func isBefore(_ lhs: Measured, _ rhs: Measured) -> Bool {
            lhs.distance == rhs.distance
                ? lhs.pin.createdAt > rhs.pin.createdAt
                : lhs.distance < rhs.distance
        }
    }
}
