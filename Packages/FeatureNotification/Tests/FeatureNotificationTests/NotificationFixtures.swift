import Domain
import Foundation

/// 알림 테스트가 함께 쓰는 도메인 값. 두 스위트가 같은 방·핀을 따로 짓고 있어 한곳으로 모았다
/// (`PinFixture` 선례 — FeatureArchive·PlaceDetailUI 테스트도 같은 방식이다).
enum NotificationFixture {
    static let now = Date(timeIntervalSince1970: 1_700_000_000)

    static let room = Room(
        id: "room-1", type: .shared, name: "맛집 탐방", description: nil, color: .cyan,
        ownerId: "u1", createdAt: now, pinCount: 3, memberCount: 2, users: []
    )

    static let pin = Pin(
        id: PinID("pin-0"),
        roomID: room.id,
        place: Place(
            id: PlaceID("place-0"), name: "패스트리 순간", address: "서울 성동구",
            coordinate: Coordinate(latitude: 37.5443, longitude: 127.0557)
        ),
        category: .worthVisiting,
        createdAt: now
    )
}

/// 이동 대상 조회 스텁. 성공값을 `nil` 로 두면 그 조회가 실패한다.
struct StubOpenDestination: FetchPinDetailUseCase, FetchRoomUseCase {
    var pin: Pin? = NotificationFixture.pin
    var room: Room? = NotificationFixture.room

    func execute(pinID: PinID) async throws -> PinDetail {
        guard let pin else { throw DomainError.pinsFetchFailed }
        return PinDetail(pin: pin, sourceURL: nil)
    }

    func execute(id: String) async throws -> Room {
        guard let room else { throw DomainError.roomsFetchFailed }
        return room
    }
}
