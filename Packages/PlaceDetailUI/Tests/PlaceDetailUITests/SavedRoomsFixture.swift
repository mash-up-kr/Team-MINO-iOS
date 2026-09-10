import Foundation
import Domain

/// 저장된 방 조회를 즉답시키는 스텁 — 목록·실패·취소를 골라 재생한다.
///
/// 장소 상세 테스트 대부분은 저장된 방을 보지 않으므로 기본값을 빈 목록으로 둔다
/// (그러면 '저장된 방' 버튼이 비활성인 평소 상태가 된다).
struct StubFetchSavedRooms: FetchSavedRoomsUseCase {
    enum Outcome: Sendable {
        case rooms([SavedRoom])
        case failure(DomainError)
        case cancelled
    }

    var outcome: Outcome = .rooms([])

    func execute(pin: Pin) async throws -> [SavedRoom] {
        switch outcome {
        case .rooms(let rooms): return rooms
        case .failure(let error): throw error
        case .cancelled: throw CancellationError()
        }
    }
}

/// 저장된 방 목록에 쓸 픽스처. 이름·색만 다른 공유 방이라 검증에 필요한 값(id·매칭 핀)만 받는다.
///
/// `pinID` 기본값은 방 id 에서 지어 낸다 — 서버가 매칭 핀을 주는 것이 정상 경로라 그쪽을 기본으로
/// 두고, "핀을 못 집은 방" 은 부르는 쪽이 `nil` 을 명시한다.
enum SavedRoomFixture {
    static func room(
        _ id: String,
        name: String = "우리 동네 맛집",
        pinCount: Int = 3,
        pinID: PinID? = nil
    ) -> SavedRoom {
        SavedRoom(
            room: Room(
                id: id, type: .shared, name: name, description: nil, color: .orange,
                ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
                pinCount: pinCount, memberCount: 2, users: []
            ),
            pinID: pinID ?? PinID("pin-in-\(id)")
        )
    }
}
