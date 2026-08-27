import Foundation

/// 저장한 장소(Pin)를 다른 방에 담는 저장소 추상.
/// 구현체(Data 계층)가 API/DB/Mock 중 무엇을 쓰는지 Domain 은 알지 못한다.
public protocol SavePinRepository: Sendable {
    /// 장소 하나를 여러 방에 저장한다. 이미 그 방에 있는 장소는 서버가 중복으로 담지 않는다.
    func save(pinID: PinID, toRoomIDs roomIDs: Set<String>) async throws
    /// "다른 방에 공유" 후보 목록 — 방과, 그 방에 이 장소가 이미 있는지.
    ///
    /// 방 목록과 `alreadySaved` 를 한 조회로 받는다. 나눠 받으면 화면이 두 소스를 대조해야 하고,
    /// 그 사이에 다른 기기가 저장하면 체크 상태가 어긋난다.
    func shareTargets(pinID: PinID) async throws -> [ShareTarget]
}
