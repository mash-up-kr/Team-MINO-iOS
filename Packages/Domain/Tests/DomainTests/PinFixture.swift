import Foundation
@testable import Domain

/// Pin 테스트 픽스처. `Place` 가 `Pin` 안으로 들어오면서 생성 인자가 늘어, 케이스마다 장소를
/// 손으로 짓지 않도록 여기 한 곳에 모은다. 검증 대상이 아닌 필드는 기본값으로 채운다.
enum PinFixture {
    static func place(
        id: String = "place-1",
        name: String = "레이어스튜디오 10",
        address: String = "서울 성동구 상원4길 10",
        coordinate: Coordinate = Coordinate(latitude: 37.5443, longitude: 127.0557),
        category: String? = nil
    ) -> Place {
        Place(
            id: PlaceID(id),
            name: name,
            address: address,
            coordinate: coordinate,
            category: category
        )
    }

    static func pin(
        id: String = "pin-1",
        roomID: String = "room-1",
        createdAt: Date = Date(timeIntervalSince1970: 0),
        place: Place? = nil,
        images: [URL] = [],
        createdBy: MemberProfile? = nil,
        commentCount: Int = 0
    ) -> Pin {
        Pin(
            id: PinID(id),
            roomID: roomID,
            place: place ?? Self.place(id: "place-\(id)", name: "장소 \(id)", address: "주소 \(id)"),
            images: images,
            createdBy: createdBy,
            commentCount: commentCount,
            category: .worthVisiting,
            createdAt: createdAt
        )
    }

    static func room(id: String = "room-1", name: String = "방 \(1)") -> Room {
        Room(
            id: id,
            type: .personal,
            name: name,
            description: nil,
            color: nil,
            ownerId: "me",
            createdAt: Date(timeIntervalSince1970: 0),
            pinCount: 0,
            memberCount: 1,
            users: []
        )
    }
}
