import Networking

/// 내 프로필(유저) 엔드포인트. 경로가 Repository 메서드 안에 흩어지지 않게 여기 모은다.
enum UserAPI {
    private static let base = "api/v1/users"

    /// 유저 등록 (+ 서버가 개인방을 함께 만든다).
    ///
    /// `.unregisteredUser` — 토큰은 **반드시** 보내야 하지만(서버가 그 uid 로 누구를 등록할지 안다)
    /// 등록 여부는 묻지 않는다. `.full` 로 두면 최초 진입이 통째로 막힌다.
    static func register(_ body: RegisterProfileRequestDTO) -> Endpoint<ProfileDTO> {
        Endpoint(path: base, method: .post, body: .json(body), auth: .unregisteredUser)
    }

    static func me() -> Endpoint<ProfileDTO> {
        Endpoint(path: "\(base)/me")
    }

    /// 부분 수정 — 넘긴 항목만 바뀐다.
    static func updateMe(_ body: UpdateProfileRequestDTO) -> Endpoint<ProfileDTO> {
        Endpoint(path: "\(base)/me", method: .patch, body: .json(body))
    }

    /// 디바이스 푸시 토큰 등록·갱신(등록과 갱신이 같은 요청이다).
    ///
    /// 재설치로 새 유저가 생기면 **서버가 이전 유저 행의 토큰을 회수한다**(스펙 description) —
    /// 클라이언트가 옛 토큰을 지울 필요가 없다. **삭제 엔드포인트는 없다** — 알림을 끄는 건
    /// 기기에서 토큰을 무효화하는 방식이다(`PushRegistrationRepository`).
    static func updatePushToken(_ body: UpdatePushTokenRequestDTO) -> Endpoint<OkResponse> {
        Endpoint(path: "\(base)/me/push-token", method: .put, body: .json(body))
    }
}
