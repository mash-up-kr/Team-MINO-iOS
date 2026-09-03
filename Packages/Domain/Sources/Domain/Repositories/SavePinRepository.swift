import Foundation

/// 저장한 장소(Pin)를 다른 방에 담는 저장소 추상.
/// 구현체(Data 계층)가 API/DB/Mock 중 무엇을 쓰는지 Domain 은 알지 못한다.
public protocol SavePinRepository: Sendable {
    /// 장소 하나를 여러 방에 저장한다. 이미 그 방에 있는 장소는 서버가 중복으로 담지 않는다.
    func save(pinID: PinID, toRoomIDs roomIDs: Set<String>) async throws
}

/// "다른 방에 공유" 후보를 읽는 저장소 추상.
///
/// 쓰기(``SavePinRepository``)와 나눠 둔 이유는 **둘의 준비 상태가 다르기** 때문이다 —
/// 저장은 실 API(`POST /api/v1/pins/{pinId}/duplicate`)가 있지만, "이 장소가 어느 방에
/// 들어 있는지" 를 주는 API 는 아직 없다. 한 프로토콜로 묶어 두면 한쪽만 실 구현으로
/// 갈아끼울 수 없다. 쓰는 쪽도 자기가 필요한 절반만 본다(ISP).
public protocol ShareTargetRepository: Sendable {
    /// "다른 방에 공유" 후보 목록 — 방과, 그 방에 이 **장소**가 이미 있는지.
    ///
    /// 방 목록과 `alreadySaved` 를 한 조회로 받는다. 나눠 받으면 화면이 두 소스를 대조해야 하고,
    /// 그 사이에 다른 기기가 저장하면 체크 상태가 어긋난다.
    ///
    /// 핀 id 가 아니라 **장소 id** 를 받는다 — 같은 장소도 방마다 핀 id 가 달라, "어느 방에
    /// 있는지" 는 장소 기준으로만 물을 수 있다(서버 `?showHasPlaceId={placeId}`).
    func shareTargets(placeID: PlaceID) async throws -> [ShareTarget]
}
