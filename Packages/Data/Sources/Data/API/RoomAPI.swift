import Foundation
import Networking

/// 방(room) 엔드포인트. 경로가 Repository 메서드 안에 흩어지지 않게 여기 모은다.
enum RoomAPI {
    private static let base = "api/v1/rooms"

    /// 내가 속한 방 목록. 나간 방은 서버가 빼고 준다.
    ///
    /// 페이지네이션이 없다 — 방 개수가 적은 화면(홈 방변경·공유 시트)만 쓰므로 서버가 전체를 준다.
    ///
    /// - Parameter showUsers: 멤버 목록을 함께 받을지. 방 카드·방 상세 헤더가 멤버 얼굴을 그리므로
    ///   기본을 `true` 로 둔다 — 빼면 그 자리가 조용히 빈다(서버가 `users` 키 자체를 생략한다).
    static func list(showUsers: Bool = true) -> Endpoint<[RoomDTO]> {
        Endpoint(
            path: base,
            queryItems: showUsers ? [URLQueryItem(name: "showUsers", value: "true")] : []
        )
    }

    /// 방 하나. 목록과 달리 **`users`·`thumbnailList` 를 주지 않고 `showUsers` 쿼리도 받지 않는다**
    /// (스펙 확인). 멤버 얼굴이 필요하면 ``members(_:)`` 를 함께 부른다.
    static func detail(_ roomId: String) -> Endpoint<RoomDTO> {
        Endpoint(path: "\(base)/\(roomId)")
    }

    /// 방 멤버 목록. 단건 상세가 멤버를 빼고 주기 때문에 있는 경로다.
    static func members(_ roomId: String) -> Endpoint<[RoomMemberDTO]> {
        Endpoint(path: "\(base)/\(roomId)/members")
    }

    static func create(_ body: SaveRoomRequestDTO) -> Endpoint<RoomDTO> {
        Endpoint(path: base, method: .post, body: .json(body))
    }

    static func update(_ roomId: String, _ body: SaveRoomRequestDTO) -> Endpoint<RoomDTO> {
        Endpoint(path: "\(base)/\(roomId)", method: .patch, body: .json(body))
    }
}
