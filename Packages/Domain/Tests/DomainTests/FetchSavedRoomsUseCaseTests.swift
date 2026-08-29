import Foundation
import Testing
@testable import Domain

private func room(_ id: String) -> Room {
    Room(
        id: id, type: .shared, name: "방 \(id)", description: nil, color: .orange,
        ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
        pinCount: 0, memberCount: 1, users: []
    )
}

/// 공유 후보 조회만 재생하는 스텁. 저장(`save`)은 이 UseCase 가 부르지 않는다.
private struct StubSavePinRepository: SavePinRepository {
    let targets: [ShareTarget]
    var error: DomainError?

    func save(pinID: PinID, toRoomIDs roomIDs: Set<String>) async throws {}

    func shareTargets(pinID: PinID) async throws -> [ShareTarget] {
        if let error { throw error }
        return targets
    }
}

struct FetchSavedRoomsUseCaseTests {
    private let pin = PinFixture.pin(id: "pin-1", roomID: "room-A")

    @Test("이미 저장된 방만 남긴다 — 담기지 않은 방은 '저장된 방'이 아니다")
    func keepsOnlyAlreadySavedRooms() async throws {
        let sut = DefaultFetchSavedRoomsUseCase(
            repository: StubSavePinRepository(targets: [
                ShareTarget(room: room("room-B"), alreadySaved: true),
                ShareTarget(room: room("room-C"), alreadySaved: false),
            ])
        )

        let rooms = try await sut.execute(pin: pin)

        #expect(rooms.map(\.id) == ["room-B"])
    }

    @Test("장소가 원래 속한 방은 뺀다 (기획 014 ② — 방 A 는 표출되지 않는다)")
    func dropsOwningRoom() async throws {
        let sut = DefaultFetchSavedRoomsUseCase(
            repository: StubSavePinRepository(targets: [
                ShareTarget(room: room("room-A"), alreadySaved: true),
                ShareTarget(room: room("room-B"), alreadySaved: true),
            ])
        )

        let rooms = try await sut.execute(pin: pin)

        #expect(rooms.map(\.id) == ["room-B"])
    }

    @Test("원래 방에만 있으면 빈 목록 — 중복 저장이 아니라 버튼이 열리지 않는다")
    func emptyWhenOnlyInOwningRoom() async throws {
        let sut = DefaultFetchSavedRoomsUseCase(
            repository: StubSavePinRepository(targets: [
                ShareTarget(room: room("room-A"), alreadySaved: true),
                ShareTarget(room: room("room-B"), alreadySaved: false),
            ])
        )

        #expect(try await sut.execute(pin: pin).isEmpty)
    }

    @Test("저장소가 준 순서를 그대로 유지한다")
    func keepsRepositoryOrder() async throws {
        let sut = DefaultFetchSavedRoomsUseCase(
            repository: StubSavePinRepository(targets: [
                ShareTarget(room: room("room-C"), alreadySaved: true),
                ShareTarget(room: room("room-A"), alreadySaved: true),
                ShareTarget(room: room("room-B"), alreadySaved: true),
            ])
        )

        #expect(try await sut.execute(pin: pin).map(\.id) == ["room-C", "room-B"])
    }

    @Test("저장소 오류를 그대로 올려보낸다 — 삼키면 화면이 '저장된 방 없음'으로 오해한다")
    func propagatesRepositoryError() async {
        let sut = DefaultFetchSavedRoomsUseCase(
            repository: StubSavePinRepository(targets: [], error: .unknown)
        )

        await #expect(throws: DomainError.unknown) {
            _ = try await sut.execute(pin: pin)
        }
    }
}
