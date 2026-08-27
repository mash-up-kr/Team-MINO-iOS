import Foundation

/// 방에 저장한 장소(Pin)를 지우는 저장소 추상.
/// 구현체(Data 계층)가 API/DB/Mock 중 무엇을 쓰는지 Domain 은 알지 못한다.
///
/// 조회(``PinRepository``)와 갈라 둔다. 목록·상세만 읽는 화면이 쓰기 메서드까지 떠안지 않게 하고,
/// 실 API 가 붙을 때 조회와 삭제가 서로 다른 엔드포인트·권한을 갖는 걸 인터페이스에 드러낸다.
public protocol PinDeletionRepository: Sendable {
    /// 장소 하나를 방에서 지운다. 반환 없이 끝나면 그 장소는 더 이상 방에 없다.
    func delete(pinID: PinID) async throws
}
