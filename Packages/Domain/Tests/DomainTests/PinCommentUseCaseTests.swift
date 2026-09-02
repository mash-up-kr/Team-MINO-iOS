import Foundation
import Testing
@testable import Domain

private let commentPin = PinID("pin-7")
private let commentAuthor = MemberProfile(id: MemberID("user-0001"), nickname: "나", avatarColor: .red)

/// 저장소가 받은 인자를 기록하고 정해진 값으로 즉답한다.
private actor StubPinPinCommentRepository: PinCommentRepository {
    private let stored: [PinComment]
    private let error: DomainError?
    private(set) var postedBodies: [String] = []
    private(set) var deleted: [(pinID: PinID, commentID: PinCommentID)] = []

    init(stored: [PinComment] = [], error: DomainError? = nil) {
        self.stored = stored
        self.error = error
    }

    func comments(pinID: PinID) async throws -> [PinComment] {
        if let error { throw error }
        return stored
    }

    func post(pinID: PinID, body: String) async throws -> PinComment {
        postedBodies.append(body)
        if let error { throw error }
        return PinComment(
            id: PinCommentID("c-new"),
            pinID: pinID,
            author: commentAuthor,
            body: body,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    func delete(pinID: PinID, commentID: PinCommentID) async throws {
        deleted.append((pinID, commentID))
        if let error { throw error }
    }
}

struct FetchPinCommentsUseCaseTests {
    @Test("저장소가 준 코멘트를 그대로 돌려준다")
    func returnsStoredComments() async throws {
        let stored = [
            PinComment(
                id: PinCommentID("c1"), pinID: commentPin, author: commentAuthor,
                body: "좋았어요", createdAt: Date(timeIntervalSince1970: 0)
            ),
        ]
        let sut = DefaultFetchPinCommentsUseCase(repository: StubPinPinCommentRepository(stored: stored))

        #expect(try await sut.execute(pinID: commentPin) == stored)
    }

    @Test("저장소 오류를 그대로 올려보낸다")
    func propagatesRepositoryError() async {
        let sut = DefaultFetchPinCommentsUseCase(repository: StubPinPinCommentRepository(error: DomainError.unknown))

        await #expect(throws: DomainError.unknown) {
            _ = try await sut.execute(pinID: commentPin)
        }
    }
}

struct PostPinCommentUseCaseTests {
    @Test("앞뒤 공백을 잘라 넘긴다")
    func trimsWhitespace() async throws {
        let repository = StubPinPinCommentRepository()
        let sut = DefaultPostPinCommentUseCase(repository: repository)

        let posted = try await sut.execute(pinID: commentPin, body: "  좋았어요\n")

        #expect(await repository.postedBodies == ["좋았어요"])
        #expect(posted.body == "좋았어요")
    }

    @Test("200자를 넘으면 잘라 넘긴다 — 서버가 거절하는 길이라 화면 카운터와 같은 값을 본다")
    func clampsToBodyLimit() async throws {
        let repository = StubPinPinCommentRepository()
        let sut = DefaultPostPinCommentUseCase(repository: repository)

        _ = try await sut.execute(pinID: commentPin, body: String(repeating: "가", count: 250))

        #expect(await repository.postedBodies == [String(repeating: "가", count: PinComment.bodyLimit)])
    }

    @Test("공백뿐이면 저장소에 닿기 전에 거절한다")
    func rejectsBlankBody() async {
        let repository = StubPinPinCommentRepository()
        let sut = DefaultPostPinCommentUseCase(repository: repository)

        await #expect(throws: DomainError.commentBodyEmpty) {
            _ = try await sut.execute(pinID: commentPin, body: "   \n ")
        }
        #expect(await repository.postedBodies.isEmpty)
    }

    @Test("저장소 오류를 그대로 올려보낸다 — 삼키면 화면이 등록된 줄 안다")
    func propagatesRepositoryError() async {
        let sut = DefaultPostPinCommentUseCase(repository: StubPinPinCommentRepository(error: DomainError.unknown))

        await #expect(throws: DomainError.unknown) {
            _ = try await sut.execute(pinID: commentPin, body: "좋았어요")
        }
    }
}

struct DeletePinCommentUseCaseTests {
    @Test("고른 코멘트의 핀·id 를 그대로 저장소에 넘긴다")
    func passesCommentIDToRepository() async throws {
        let repository = StubPinPinCommentRepository()
        let sut = DefaultDeletePinCommentUseCase(repository: repository)

        try await sut.execute(pinID: commentPin, commentID: PinCommentID("c1"))

        let deleted = await repository.deleted
        #expect(deleted.count == 1)
        #expect(deleted.first?.pinID == commentPin)
        #expect(deleted.first?.commentID == PinCommentID("c1"))
    }

    @Test("저장소 오류를 그대로 올려보낸다 — 삼키면 화면이 지워진 줄 안다")
    func propagatesRepositoryError() async {
        let sut = DefaultDeletePinCommentUseCase(repository: StubPinPinCommentRepository(error: DomainError.unknown))

        await #expect(throws: DomainError.unknown) {
            try await sut.execute(pinID: commentPin, commentID: PinCommentID("c1"))
        }
    }
}

struct PinCommentOwnershipTests {
    private let mine = PinComment(
        id: PinCommentID("c1"), pinID: commentPin, author: commentAuthor,
        body: "내가 남긴 코멘트", createdAt: Date(timeIntervalSince1970: 0)
    )

    @Test("작성자 본인이면 내 코멘트다")
    func ownedByAuthor() {
        #expect(mine.isWritten(by: MemberID("user-0001")))
    }

    @Test("닉네임이 같아도 식별자가 다르면 내 것이 아니다")
    func rejectsSameNickname() {
        let impostor = PinComment(
            id: PinCommentID("c2"), pinID: commentPin,
            author: MemberProfile(id: MemberID("user-0009"), nickname: "나", avatarColor: .blue),
            body: "동명이인 코멘트", createdAt: Date(timeIntervalSince1970: 0)
        )

        #expect(impostor.author.nickname == mine.author.nickname)
        #expect(!impostor.isWritten(by: MemberID("user-0001")))
    }

    @Test("신원을 모르면 어떤 코멘트도 내 것이 아니다")
    func rejectsUnknownViewer() {
        #expect(!mine.isWritten(by: nil))
    }
}
