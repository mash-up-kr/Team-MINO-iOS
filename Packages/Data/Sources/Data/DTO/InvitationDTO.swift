import Domain
import Foundation

/// `POST /api/v1/rooms/{roomId}/invitations` 의 `data` 알맹이.
/// envelope(`{"data": …}`)은 `HTTPClient` 가 벗기므로 래퍼 타입을 만들지 않는다.
///
/// internal 로 닫아 Domain 에 노출되지 않게 한다.
struct InviteCodeDTO: Decodable {
    /// 대문자 영문 + 숫자 6자. **링크는 서버가 주지 않는다** — 클라이언트가 `Core.DeeplinkBuilder`
    /// 로 `https://gguk.org/r/{code}` 를 조립한다(스펙 명시).
    let code: String
}

/// `GET /api/v1/invitations/{code}` 의 `data` 알맹이.
///
/// 방 미리보기라 `RoomDTO` 와 필드가 겹치지만 **재사용하지 않는다** — 이 응답에는
/// `ownerId`·`createdAt` 이 없어 `RoomDTO` 로 받으면 디코딩이 실패한다.
struct InvitationPreviewDTO: Decodable {
    let room: PreviewRoomDTO
    let inviter: PreviewInviterDTO

    struct PreviewRoomDTO: Decodable {
        let id: String
        let type: String
        let name: String
        let description: String?
        let color: String
        let pinCount: Int
        let memberCount: Int
    }

    struct PreviewInviterDTO: Decodable {
        let nickname: String
    }
}

extension InvitationPreviewDTO {
    /// 경계(Data → Domain) 변환. `RoomDTO.toDomain()` 과 같은 규약을 쓴다 —
    /// 알 수 없는 `type` 은 `shared`, 팔레트에 없는 `color` 는 `nil`.
    func toDomain() -> RoomInvitationPreview {
        RoomInvitationPreview(
            roomID: room.id,
            roomType: RoomType(rawValue: room.type) ?? .shared,
            roomName: room.name,
            roomDescription: room.description,
            roomColor: RoomColor(rawValue: room.color),
            pinCount: room.pinCount,
            memberCount: room.memberCount,
            inviterNickname: inviter.nickname
        )
    }
}

/// `POST /api/v1/rooms/{roomId}/members` 요청 본문.
struct JoinRoomRequestDTO: Encodable, Sendable {
    let inviteCode: String
}

/// 같은 엔드포인트의 응답. `{ "ok": true }` 뿐이라 읽을 값이 없지만,
/// `Endpoint` 가 응답 타입을 요구하므로 빈 껍데기를 둔다.
struct JoinRoomResponseDTO: Decodable {
    let ok: Bool
}
