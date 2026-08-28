import Foundation

/// 장소(핀)에 달린 코멘트의 저장소 추상.
/// 구현체(Data 계층)가 API/DB/Mock 중 무엇을 쓰는지 Domain 은 알지 못한다.
///
/// 조회·등록·삭제를 **한 프로토콜에** 둔다. 핀은 조회(``PinRepository``)와 삭제
/// (``PinDeletionRepository``)를 갈라 뒀지만 그건 목록만 읽는 화면이 여럿이라 쓰기까지
/// 떠안기지 않으려던 것이고, 코멘트는 셋을 **한 화면이 전부** 쓴다 — 나누면 같은 자원을
/// 가리키는 프로토콜만 셋이 된다.
public protocol PinCommentRepository: Sendable {
    /// 이 장소에 달린 코멘트를 오래된 것부터 돌려준다.
    func comments(pinID: PinID) async throws -> [PinComment]
    /// 코멘트를 남기고 **서버가 만든 값**을 돌려받는다.
    ///
    /// 작성자·식별자·작성 시각을 인자로 받지 않는 이유: 셋 다 서버가 정한다. 작성자를 인자로
    /// 두면 클라이언트가 남의 이름으로 쓰는 경로가 인터페이스에 생기고, 식별자를 클라이언트가
    /// 만들면 그 값이 삭제의 손잡이라 서버 id 와 어긋나는 순간 지울 수 없는 줄이 남는다.
    func post(pinID: PinID, body: String) async throws -> PinComment
    /// 코멘트 하나를 지운다. 반환 없이 끝나면 그 코멘트는 더 이상 없다.
    func delete(commentID: PinCommentID) async throws
}
