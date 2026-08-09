import Foundation

/// 방의 종류. `personal`(내 장소, 나만의 방) / `shared`(공동 방).
/// rawValue 는 API 스키마의 `type` 값과 일치한다(경계 매핑은 Data 계층 DTO 담당).
public enum RoomType: String, Equatable, Sendable {
    case personal
    case shared
}
