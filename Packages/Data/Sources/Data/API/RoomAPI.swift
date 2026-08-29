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

    static func create(_ body: SaveRoomRequestDTO) -> Endpoint<RoomDTO> {
        Endpoint(path: base, method: .post, body: .json(body))
    }

    static func update(_ roomId: String, _ body: SaveRoomRequestDTO) -> Endpoint<RoomDTO> {
        Endpoint(path: "\(base)/\(roomId)", method: .patch, body: .json(body))
    }
}
