import Foundation

/// `PUT /api/v1/users/me/push-token` 요청 바디.
///
/// 같은 `users` 리소스지만 프로필 모양과 겹치는 게 없어 `ProfileDTO.swift` 에 얹지 않았다.
/// 응답은 `{"ok": true}` 뿐이라 응답 DTO 가 없다 — `OkResponse` 를 쓴다.
struct UpdatePushTokenRequestDTO: Encodable, Sendable {
    let token: String
}
