import Foundation

/// 고유 식별자(CommentID)로 구분되는 도메인 Entity — 장소에 남긴 코멘트.
/// 프레임워크에 의존하지 않는 순수 value type 이며 Codable 을 준수하지 않는다.
public struct Comment: Equatable, Identifiable, Sendable {
    public let id: CommentID
    /// 작성자 표시 이름. "나" 같은 로컬 표시 규칙은 Feature 가 정한다.
    public let author: String
    public let body: CommentBody

    public init(id: CommentID, author: String, body: CommentBody) {
        self.id = id
        self.author = author
        self.body = body
    }
}
