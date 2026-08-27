import Domain
import Foundation
import Networking

/// 백엔드 미연결 단계용 `RoomRepository` 구현.
/// 네트워크 대신 하드코딩 JSON(Swagger `GET /api/v1/rooms` 응답 형태)을 디코드해 반환한다.
/// DTO → `toDomain()` 경계 매핑을 실제로 태우므로, 추후 네트워크 구현으로 교체해도
/// 매핑 계층은 그대로 재사용된다.
public final class MockRoomRepository: RoomRepository {
    public init() {}

    public func rooms() async throws -> [Room] {
        do {
            let response = try APIDecoder.make().decode(Envelope.self, from: Data(Self.mockJSON.utf8))
            return response.data.map { $0.toDomain() }
        } catch {
            throw DomainError.roomsFetchFailed
        }
    }

    /// 실 응답의 `{"data": …}` 를 여기서만 벗긴다. 실 API 경로에서는 `HTTPClient` 가 벗기므로
    /// envelope 래퍼 DTO 를 만들지 않는다(`Networking/Docs/AddingAPI.md`).
    private struct Envelope: Decodable {
        let data: [RoomDTO]
    }

    // 색은 서버 계약대로 **이름**이다(hex 아님). "내 장소"는 색을 고른 적이 없어 `gray` 다.
    private static let mockJSON = """
    {
      "data": [
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "type": "personal",
          "name": "내 장소",
          "description": null,
          "color": "gray",
          "ownerId": "user-0001",
          "createdAt": "2026-08-01T09:00:00Z",
          "pinCount": 0,
          "memberCount": 1,
          "users": [
            { "userId": "user-0001", "nickname": "나", "avatar": { "id": 1 }, "isOwner": true, "joinedAt": "2026-08-01T09:00:00Z" }
          ]
        },
        {
          "id": "00000000-0000-0000-0000-000000000002",
          "type": "shared",
          "name": "우리 동네 맛집",
          "description": "친구들이랑 같이 저장하는 곳",
          "color": "orange",
          "ownerId": "user-0001",
          "createdAt": "2026-08-03T12:30:00Z",
          "pinCount": 12,
          "memberCount": 3,
          "users": [
            { "userId": "user-0001", "nickname": "나", "avatar": { "id": 1 }, "isOwner": true, "joinedAt": "2026-08-03T12:30:00Z" },
            { "userId": "user-0002", "nickname": "지훈", "avatar": { "id": 2 }, "isOwner": false, "joinedAt": "2026-08-03T13:00:00Z" },
            { "userId": "user-0003", "nickname": "서연", "avatar": { "id": 3 }, "isOwner": false, "joinedAt": "2026-08-03T13:10:00Z" }
          ]
        },
        {
          "id": "00000000-0000-0000-0000-000000000003",
          "type": "shared",
          "name": "가고싶은 카페",
          "description": "분위기 좋은 카페 모음",
          "color": "blue",
          "ownerId": "user-0002",
          "createdAt": "2026-08-05T18:00:00Z",
          "pinCount": 5,
          "memberCount": 2,
          "users": [
            { "userId": "user-0002", "nickname": "지훈", "avatar": { "id": 2 }, "isOwner": true, "joinedAt": "2026-08-05T18:00:00Z" },
            { "userId": "user-0001", "nickname": "나", "avatar": { "id": 1 }, "isOwner": false, "joinedAt": "2026-08-05T18:20:00Z" }
          ]
        },
        {
          "id": "00000000-0000-0000-0000-000000000004",
          "type": "shared",
          "name": "제주 여행",
          "description": "제주 3박 4일 코스",
          "color": "green",
          "ownerId": "user-0003",
          "createdAt": "2026-08-06T08:15:00Z",
          "pinCount": 8,
          "memberCount": 4,
          "users": [
            { "userId": "user-0003", "nickname": "서연", "avatar": { "id": 3 }, "isOwner": true, "joinedAt": "2026-08-06T08:15:00Z" },
            { "userId": "user-0001", "nickname": "나", "avatar": { "id": 1 }, "isOwner": false, "joinedAt": "2026-08-06T09:00:00Z" },
            { "userId": "user-0002", "nickname": "지훈", "avatar": { "id": 2 }, "isOwner": false, "joinedAt": "2026-08-06T09:05:00Z" },
            { "userId": "user-0004", "nickname": "민준", "avatar": { "id": 4 }, "isOwner": false, "joinedAt": "2026-08-06T10:00:00Z" }
          ]
        }
      ]
    }
    """
}
