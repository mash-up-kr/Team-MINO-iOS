import Foundation

/// `POST /api/v1/rooms/pins` 요청 본문.
/// 응답 DTO 는 없다 — 202 에 본문이 없다(`PinAPI.create` 참조).
struct CreatePinRequestDTO: Encodable, Sendable {
    let url: URL
    /// 최소 1개(스펙). 화면이 "방을 하나라도 골라야 저장 활성"을 지키므로 빈 배열은 오지 않는다.
    let roomIds: [String]
}
