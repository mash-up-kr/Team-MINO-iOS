import Foundation
import Testing
@testable import Domain

private func room(_ id: String, type: RoomType = .shared) -> Room {
    Room(
        id: id, type: type, name: "방 \(id)", description: nil, color: .orange,
        ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
        pinCount: 0, memberCount: 1, users: []
    )
}

private struct StubRoomRepository: RoomRepository {
    let result: [Room]
    var error: DomainError?

    func rooms() async throws -> [Room] {
        if let error { throw error }
        return result
    }
}

struct FetchRoomsUseCaseTests {
    @Test("개인방이 중간에 있어도 맨 앞으로 온다")
    func movesPersonalRoomToFront() async throws {
        let sut = DefaultFetchRoomsUseCase(
            repository: StubRoomRepository(result: [
                room("room-A"),
                room("room-B", type: .personal),
                room("room-C"),
            ])
        )

        let rooms = try await sut.execute()

        #expect(rooms.map(\.id) == ["room-B", "room-A", "room-C"])
    }

    @Test("공동방끼리는 서버가 준 상대 순서를 유지한다 — 방향은 디자인 확인 대기")
    func keepsOtherRoomsRelativeOrder() async throws {
        let sut = DefaultFetchRoomsUseCase(
            repository: StubRoomRepository(result: [
                room("room-C"),
                room("room-A", type: .personal),
                room("room-B"),
            ])
        )

        let rooms = try await sut.execute()

        #expect(rooms.map(\.id) == ["room-A", "room-C", "room-B"])
    }

    @Test("개인방이 없으면 입력 순서 그대로")
    func keepsOrderWhenNoPersonalRoom() async throws {
        let sut = DefaultFetchRoomsUseCase(
            repository: StubRoomRepository(result: [
                room("room-A"),
                room("room-B"),
                room("room-C"),
            ])
        )

        let rooms = try await sut.execute()

        #expect(rooms.map(\.id) == ["room-A", "room-B", "room-C"])
    }

    @Test("빈 배열은 빈 배열 그대로")
    func returnsEmptyForEmptyInput() async throws {
        let sut = DefaultFetchRoomsUseCase(repository: StubRoomRepository(result: []))

        #expect(try await sut.execute().isEmpty)
    }

    @Test("개인방이 여러 개인 비정상 응답도 전부 앞으로, 상대 순서는 유지")
    func movesAllPersonalRoomsToFrontWhenMultiple() async throws {
        let sut = DefaultFetchRoomsUseCase(
            repository: StubRoomRepository(result: [
                room("room-A"),
                room("room-B", type: .personal),
                room("room-C"),
                room("room-D", type: .personal),
            ])
        )

        let rooms = try await sut.execute()

        #expect(rooms.map(\.id) == ["room-B", "room-D", "room-A", "room-C"])
    }

    @Test("저장소 오류를 그대로 올려보낸다")
    func propagatesRepositoryError() async {
        let sut = DefaultFetchRoomsUseCase(
            repository: StubRoomRepository(result: [], error: .roomsFetchFailed)
        )

        await #expect(throws: DomainError.roomsFetchFailed) {
            _ = try await sut.execute()
        }
    }
}
