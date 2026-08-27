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
