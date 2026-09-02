import Foundation

/// 장소 상세에 달린 코멘트를 읽는다 (기획 005-1 — "친구들의 코멘트").
public protocol FetchPinCommentsUseCase: Sendable {
    func execute(pinID: PinID) async throws -> [PinComment]
}

/// 이 장소에 코멘트를 남긴다 (기획 005-1 — 입력창 + 등록).
public protocol PostPinCommentUseCase: Sendable {
    /// - Parameter body: 사용자가 친 원문. 앞뒤 공백 제거와 상한 절단은 **이 유스케이스가** 맡는다.
    /// - Returns: 서버가 식별자·작성자·작성 시각을 채워 돌려준 코멘트.
    func execute(pinID: PinID, body: String) async throws -> PinComment
}

/// 내가 남긴 코멘트를 지운다 (기획 005-1 ⑭).
/// 누가 지울 수 있는지(``PinComment/isWritten(by:)``)는 서버가 최종 판정한다.
public protocol DeletePinCommentUseCase: Sendable {
    /// - Parameter pinID: 삭제 경로가 핀 하위라 코멘트 id 만으로는 부족하다
    ///   (``PinCommentRepository/delete(pinID:commentID:)``).
    func execute(pinID: PinID, commentID: PinCommentID) async throws
}

public struct DefaultFetchPinCommentsUseCase: FetchPinCommentsUseCase {
    private let repository: PinCommentRepository

    public init(repository: PinCommentRepository) {
        self.repository = repository
    }

    public func execute(pinID: PinID) async throws -> [PinComment] {
        try await repository.comments(pinID: pinID)
    }
}

public struct DefaultPostPinCommentUseCase: PostPinCommentUseCase {
    private let repository: PinCommentRepository

    public init(repository: PinCommentRepository) {
        self.repository = repository
    }

    /// 다듬기(공백 제거·상한 절단)를 화면이 아니라 여기서 한다 — 상한은 서버가 거절하는 길이라
    /// 비즈니스 규칙이고, 입력 경로가 늘어도 규칙이 한 곳에 남는다.
    public func execute(pinID: PinID, body: String) async throws -> PinComment {
        let trimmed = String(
            body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(PinComment.bodyLimit)
        )
        guard !trimmed.isEmpty else { throw DomainError.commentBodyEmpty }
        return try await repository.post(pinID: pinID, body: trimmed)
    }
}

public struct DefaultDeletePinCommentUseCase: DeletePinCommentUseCase {
    private let repository: PinCommentRepository

    public init(repository: PinCommentRepository) {
        self.repository = repository
    }

    public func execute(pinID: PinID, commentID: PinCommentID) async throws {
        try await repository.delete(pinID: pinID, commentID: commentID)
    }
}
