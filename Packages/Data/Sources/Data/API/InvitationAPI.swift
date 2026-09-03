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
}
