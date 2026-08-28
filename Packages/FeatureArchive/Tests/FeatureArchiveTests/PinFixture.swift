import Foundation
import Domain

/// 테스트용 `Pin` 생성기. `Place` 가 `Pin` 안으로 들어오면서 인자가 늘어, 케이스마다 장소를
/// 손으로 짓지 않도록 한 곳에 모은다. 검증 대상이 아닌 필드는 기본값으로 채운다.
enum PinFixture {
    /// 자오선(같은 경도) 위로 `meters` 만큼 북쪽인 좌표.
    /// 경도가 같으면 Haversine 이 `R·Δφ` 로 떨어져 "기준점에서 정확히 N미터" 를 지정할 수 있다.
    /// 상수는 `Domain.Coordinate` 가 쓰는 지구 평균 반지름(m)과 같은 값이다.
    static func coordinate(_ meters: Double, northOf origin: Coordinate) -> Coordinate {
        Coordinate(
            latitude: origin.latitude + meters / 6_371_008.8 * 180 / .pi,
            longitude: origin.longitude
        )
    }

    static func pin(
        id: PinID,
        roomID: String,
        category: PinCategory,
        title: String,
        address: String,
        coordinate: Coordinate = Coordinate(latitude: 37.5443, longitude: 127.0557),
        placeCategory: String? = nil,
        images: [URL] = [],
        createdBy: MemberProfile? = nil,
        commentCount: Int = 0,
        createdAt: Date
    ) -> Pin {
        Pin(
            id: id,
            roomID: roomID,
            place: Place(
                id: PlaceID("place-\(id.value)"),
                name: title,
                address: address,
                coordinate: coordinate,
                category: placeCategory
            ),
            images: images,
            createdBy: createdBy,
            commentCount: commentCount,
            category: category,
            createdAt: createdAt
        )
    }
}
