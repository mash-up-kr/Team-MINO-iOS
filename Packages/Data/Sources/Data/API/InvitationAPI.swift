import Networking

/// 초대 엔드포인트. 경로가 `rooms/{id}` 아래에 있지만 리소스는 초대라 방과 나눠 둔다.
enum InvitationAPI {
    /// 내 초대 코드 발급.
    ///
    /// 멤버당 하나라 **다시 불러도 같은 코드**가 온다(만료·재발급 없음). POST 지만 몇 번을 불러도
    /// 결과가 같아, 화면이 코드를 들고 다닐 필요 없이 필요할 때마다 부르면 된다.
    static func create(roomId: String) -> Endpoint<InviteCodeDTO> {
        Endpoint(path: "api/v1/rooms/\(roomId)/invitations", method: .post)
    }

    /// 초대 코드로 방 미리보기. **인증이 필요 없다**(`auth: .none`) — 앱 설치 전·온보딩 전 진입을
    /// 위해 서버가 열어 둔 경로다. 합류에 필요한 `roomId` 를 얻는 유일한 수단이기도 하다.
    static func preview(code: String) -> Endpoint<InvitationPreviewDTO> {
        Endpoint(path: "api/v1/invitations/\(code)", auth: .none)
    }

    /// 방 합류. 코드가 이 방의 것인지는 서버가 검증하고, **이미 멤버면 오류 대신 멱등 응답**을 준다.
    static func join(roomId: String, body: JoinRoomRequestDTO) -> Endpoint<JoinRoomResponseDTO> {
        Endpoint(path: "api/v1/rooms/\(roomId)/members", method: .post, body: .json(body))
    }
}
