import Foundation
import Domain

/// 백엔드 미연결 단계용 `SavePinRepository` 구현.
///
/// 저장 API 가 없어 **어느 방에 담았는지를 메모리에 들고 있는다.** 그냥 성공만 돌려주면
/// 011-1 ④(이미 저장된 방은 체크된 채 비활성)와 014(저장된 방 목록)가 목업에서도 동작하지
/// 않는다 — 저장 직후 다시 열어도 아무 방에도 안 담긴 것처럼 보인다.
/// 네트워크처럼 잠깐 기다렸다 성공하는 지연은 시트의 저장 중/완료 전이를 실물처럼 보기 위한 것이다.
///
/// 추후 네트워크 `SavePinRepositoryImpl`(DTO → `toDomain()` 매핑) 로 교체하면 이 파일만 지운다.
/// 그때 실패 경로(중복 저장 알림 등)도 함께 붙는다.
public final class MockSavePinRepository: SavePinRepository {
    private let rooms: RoomRepository
    private let pins: PinDetailRepository
    private let saved = SavedPinIndex()

    /// - Parameter pins: 핀이 **원래 속한 방**을 알아내는 데 쓴다. 그 방도 "이미 저장됨"이라
    ///   목록에서 체크·비활성으로 나와야 하는데, 핀 id 만으로는 알 수 없다.
    public init(rooms: RoomRepository, pins: PinDetailRepository) {
        self.rooms = rooms
        self.pins = pins
    }

    public func save(pinID: PinID, toRoomIDs roomIDs: Set<String>) async throws {
        try? await Task.sleep(for: .milliseconds(300))
        await saved.add(pinID: pinID, roomIDs: roomIDs)
    }

    public func shareTargets(pinID: PinID) async throws -> [ShareTarget] {
        let all = try await rooms.rooms()
        var owning = await saved.roomIDs(for: pinID)
        if let home = try? await pins.pinDetail(id: pinID).pin.roomID {
            owning.insert(home)
        }
        return all.map { ShareTarget(room: $0, alreadySaved: owning.contains($0.id)) }
    }
}

/// 어떤 핀이 어느 방에 담겼는지. 목이 프로세스 수명 동안만 기억한다.
private actor SavedPinIndex {
    private var index: [String: Set<String>] = [:]

    func add(pinID: PinID, roomIDs: Set<String>) {
        index[pinID.value, default: []].formUnion(roomIDs)
    }

    func roomIDs(for pinID: PinID) -> Set<String> {
        index[pinID.value] ?? []
    }
}
