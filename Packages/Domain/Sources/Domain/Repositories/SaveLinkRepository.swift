import Foundation

/// 공유받은 링크를 방에 담는 컬렉션 인터페이스.
///
/// `SavePinRepository`(이미 있는 핀을 다른 방에 복제)와 다르다 — 이쪽은 **아직 핀이 아닌 링크**를
/// 넘기고, 장소 추출은 서버가 비동기로 한다. 그래서 성공해도 돌려줄 `Pin` 이 없다.
public protocol SaveLinkRepository: Sendable {
    /// 고른 방들에 링크를 담는다.
    ///
    /// 방 목록을 한 번에 넘기고 방마다 담는 일은 서버가 한다 — 부분 성공을 클라이언트가
    /// 조립하지 않는다. 실패는 통째로 던진다.
    func save(url: URL, toRoomIDs roomIDs: Set<String>) async throws
}
