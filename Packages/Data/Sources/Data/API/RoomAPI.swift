import Networking

/// 방(room) 엔드포인트. 경로가 Repository 메서드 안에 흩어지지 않게 여기 모은다.
enum RoomAPI {
    private static let base = "api/v1/rooms"

    static func create(_ body: SaveRoomRequestDTO) -> Endpoint<RoomDTO> {
        Endpoint(path: base, method: .post, body: .json(body))
    }

    static func update(_ roomId: String, _ body: SaveRoomRequestDTO) -> Endpoint<RoomDTO> {
        Endpoint(path: "\(base)/\(roomId)", method: .patch, body: .json(body))
    }
}
