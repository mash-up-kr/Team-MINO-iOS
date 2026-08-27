import Foundation

/// 공유받은 링크를 방에 담는 컬렉션 인터페이스.
///
/// `SavePinRepository`(이미 있는 핀을 다른 방에 복제)와 다르다 — 이쪽은 **아직 핀이 아닌 링크**를
/// 넘기고, 장소 추출은 서버가 비동기로 한다. 그래서 성공해도 돌려줄 `Pin` 이 없다.
public protocol SaveLinkRepository: Sendable {
    /// 고른 방들에 링크를 담는다. **하나라도 실패하면 던진다.**
    ///
    /// 방마다 요청이 따로 나가므로 일부만 성공할 수 있다. 이미 성공한 방은 되돌리지 않는다
    /// (서버에 취소 API 가 없고, 사용자가 의도한 저장이라 지울 이유도 없다).
    func save(url: URL, toRoomIDs roomIDs: Set<String>) async throws
}
