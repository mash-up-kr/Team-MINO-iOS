import Foundation

/// `POST /api/v1/rooms/{roomId}/pins` 요청 본문.
/// 응답 DTO 는 없다 — 202 에 본문이 없다(`PinAPI.create` 참조).
struct CreatePinRequestDTO: Encodable, Sendable {
    let url: URL
}
