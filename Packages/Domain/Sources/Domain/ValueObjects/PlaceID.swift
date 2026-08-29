import Foundation

/// 장소(Place) 식별자 Value Object. 값 자체로 동등성을 비교하며 불변이다.
///
/// 같은 장소가 여러 방에 저장되면 핀은 달라도 이 id 는 같다 —
/// "이 장소가 그 방에 이미 있나" 판정(`RoomRepository.shareTargets`)이 이 값을 쓴다.
public struct PlaceID: Equatable, Hashable, Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}
