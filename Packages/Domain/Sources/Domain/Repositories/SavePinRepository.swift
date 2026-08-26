import Foundation

/// 저장한 장소(Pin)를 다른 방에 담는 저장소 추상.
/// 구현체(Data 계층)가 API/DB/Mock 중 무엇을 쓰는지 Domain 은 알지 못한다.
public protocol SavePinRepository: Sendable {
    /// 장소 하나를 여러 방에 저장한다. 이미 그 방에 있는 장소는 서버가 중복으로 담지 않는다.
    func save(pinID: PinID, toRoomIDs roomIDs: Set<String>) async throws
}
