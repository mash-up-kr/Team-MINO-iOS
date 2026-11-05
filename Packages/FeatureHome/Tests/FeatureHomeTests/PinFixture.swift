import Foundation
import Domain

/// 테스트용 `Pin`·`PinCard` 생성기. `Place` 가 `Pin` 안으로 들어오면서 인자가 늘어, 케이스마다 장소를
/// 손으로 짓지 않도록 한 곳에 모은다. 검증 대상이 아닌 필드는 기본값으로 채운다.
enum PinFixture {
    /// 홈 카드 한 장 — 덱 테스트는 라벨까지 든 ``PinCard`` 를 쓴다.
    static func card(
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
    ) -> PinCard {
        PinCard(
            pin: pin(
                id: id, roomID: roomID, title: title, address: address, coordinate: coordinate,
                placeCategory: placeCategory, images: images, createdBy: createdBy,
                commentCount: commentCount, createdAt: createdAt
            ),
            category: category
        )
    }

    static func pin(
        id: PinID,
        roomID: String,
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
            createdAt: createdAt
        )
    }
}
