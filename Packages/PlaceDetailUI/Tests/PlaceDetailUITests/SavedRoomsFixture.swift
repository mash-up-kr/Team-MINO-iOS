import Foundation
import Domain

/// 저장된 방 조회를 즉답시키는 스텁 — 목록·실패·취소를 골라 재생한다.
///
/// 장소 상세 테스트 대부분은 저장된 방을 보지 않으므로 기본값을 빈 목록으로 둔다
/// (그러면 '저장된 방' 버튼이 비활성인 평소 상태가 된다).
struct StubFetchSavedRooms: FetchSavedRoomsUseCase {
    enum Outcome: Sendable {
        case rooms([Room])
        case failure(DomainError)
        case cancelled
    }

    var outcome: Outcome = .rooms([])

    func execute(pin: Pin) async throws -> [Room] {
        switch outcome {
        case .rooms(let rooms): return rooms
        case .failure(let error): throw error
        case .cancelled: throw CancellationError()
        }
    }
}

/// 저장된 방 목록에 쓸 방 픽스처. 이름·색만 다른 공유 방이라 검증에 필요한 값(id)만 인자로 받는다.
enum SavedRoomFixture {
    static func room(_ id: String, name: String = "우리 동네 맛집", pinCount: Int = 3) -> Room {
        Room(
            id: id, type: .shared, name: name, description: nil, color: .orange,
            ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
            pinCount: pinCount, memberCount: 2, users: []
        )
    }
}
