import Foundation
import Networking

/// 핀(pin) 엔드포인트. 경로는 방 하위(`rooms/{id}/pins`)지만 다루는 리소스는 핀이라 여기 둔다.
enum PinAPI {
    /// 인스타그램 링크에서 장소를 추출해 방에 핀을 추가한다.
    ///
    /// **202 Accepted 에 본문이 없다** — 서버가 추출을 비동기로 하므로 돌려줄 핀이 아직 없다.
    /// `OkResponse` 로 받는 이유는 클라이언트가 빈 본문을 그 타입일 때만 성공으로 통과시키기
    /// 때문이다(`URLSessionHTTPClient` 의 빈 본문 처리).
    static func create(roomID: String, url: URL) -> Endpoint<OkResponse> {
        Endpoint(
            path: "api/v1/rooms/\(roomID)/pins",
            method: .post,
            body: .json(CreatePinRequestDTO(url: url))
        )
    }
}
