import Foundation
import Domain

/// 백엔드 미연결 단계용 `RoomRepository` 구현.
/// 네트워크 대신 하드코딩 JSON(Swagger `GET /api/v1/rooms` 응답 형태)을 디코드해 반환한다.
/// DTO → `toDomain()` 경계 매핑을 실제로 태우므로, 추후 네트워크 `RoomRepositoryImpl` 로 교체해도
/// 매핑 계층은 그대로 재사용된다.
public final class MockRoomRepository: RoomRepository {
    public init() {}

    public func rooms() async throws -> [Room] {
        do {
            let response = try JSONDecoder().decode(RoomsResponseDTO.self, from: Data(Self.mockJSON.utf8))
            return response.data.map { $0.toDomain() }
        } catch {
            throw DomainError.roomsFetchFailed
        }
    }

    private static let mockJSON = """
    {
      "data": [
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "type": "personal",
          "name": "내 장소",
          "description": null,
          "color": "#FEECFB",
          "ownerId": "user-0001",
          "inviteCode": "MYROOM01",
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
          "color": "#FEF4E6",
          "ownerId": "user-0001",
          "inviteCode": "FOOD1234",
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
          "color": "#EAF2FE",
          "ownerId": "user-0002",
          "inviteCode": "CAFE5678",
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
          "color": "#D9FFE6",
          "ownerId": "user-0003",
          "inviteCode": "JEJU9012",
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
