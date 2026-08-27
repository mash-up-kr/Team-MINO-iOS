import Foundation
import Testing
import Domain
@testable import Data

/// 목이 "지운 걸 기억한다"는 것만 검증한다. 그냥 성공만 돌려주는 목이면 시트를 닫았다 다시 열
/// 때마다 지운 장소가 되살아나는데, 화면 리듀서 테스트로는 그 회귀가 잡히지 않는다.
@Suite("MockPinRepository 삭제")
struct MockPinRepositoryTests {
    private let room = Room(
        id: "room-1", type: .personal, name: "내 방", description: nil, color: .gray,
        ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
        pinCount: 10, memberCount: 1, users: []
    )

    @Test("지운 장소는 같은 방을 다시 조회해도 오지 않는다")
    func delete_removesPinFromNextFetch() async throws {
        let sut = MockPinRepository()
        let before = try await sut.pins(room: room, page: 0, filter: .recommended)
        let target = try #require(before.first)

        try await sut.delete(pinID: target.id)
        let after = try await sut.pins(room: room, page: 0, filter: .recommended)

        #expect(!after.contains { $0.id == target.id })
        #expect(after.count == before.count - 1)
    }

    @Test("지우지 않은 장소는 그대로 남는다")
    func delete_keepsOtherPins() async throws {
        let sut = MockPinRepository()
        let before = try await sut.pins(room: room, page: 0, filter: .recommended)
        let target = try #require(before.first)

        try await sut.delete(pinID: target.id)
        let after = try await sut.pins(room: room, page: 0, filter: .recommended)

        #expect(after.map(\.id) == before.dropFirst().map(\.id))
    }

    @Test("지운 뒤에도 상세 조회는 닿는다 — 이미 열려 있던 화면이 오류로 바뀌지 않아야 한다")
    func delete_keepsDetailReachable() async throws {
        let sut = MockPinRepository()
        let before = try await sut.pins(room: room, page: 0, filter: .recommended)
        let target = try #require(before.first)

        try await sut.delete(pinID: target.id)
        let detail = try await sut.pinDetail(id: target.id)

        #expect(detail.pin.id == target.id)
    }
}
