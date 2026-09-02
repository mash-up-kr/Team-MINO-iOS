import Foundation
import Domain

/// 코멘트 유스케이스 스텁 묶음. 세 스위트(`PlaceDetailReducerTests`·`PlaceDetailCommentTests`·
/// `PlaceDetailSavedRoomsTests`)가 같은 스텁을 쓴다 — 파일마다 따로 두면 결과 모양이 갈라진다.

/// 코멘트 조회를 즉답시키는 스텁 — 성공·실패·취소를 골라 재생한다.
struct StubFetchPinComments: FetchPinCommentsUseCase {
    enum Outcome: Sendable {
        case comments([PinComment])
        case failure(DomainError)
        case cancelled
    }

    let outcome: Outcome

    init(outcome: Outcome = .comments([])) {
        self.outcome = outcome
    }

    func execute(pinID: PinID) async throws -> [PinComment] {
        switch outcome {
        case .comments(let comments): return comments
        case .failure(let error): throw error
        case .cancelled: throw CancellationError()
        }
    }
}

/// 코멘트 등록을 즉답시키는 스텁.
///
/// 성공 케이스가 **고정 코멘트가 아니라 본문을 받아 만드는 클로저**인 이유: 리듀서가 다듬은
/// 본문을 그대로 넘기는지(앞뒤 공백 제거)를 결과에서 확인해야 하기 때문이다. 고정값을 돌려주면
/// 리듀서가 무엇을 보냈든 테스트가 통과한다.
struct StubPostPinComment: PostPinCommentUseCase {
    enum Outcome: Sendable {
        case posted(@Sendable (String) -> PinComment)
        case failure(DomainError)
        case cancelled
    }

    let outcome: Outcome

    func execute(pinID: PinID, body: String) async throws -> PinComment {
        switch outcome {
        case .posted(let make): return make(body)
        case .failure(let error): throw error
        case .cancelled: throw CancellationError()
        }
    }
}

/// 코멘트 삭제를 즉답시키는 스텁.
///
/// `log` 를 넘기면 받은 인자를 적어 둔다 — 삭제 경로가 핀 하위라(`delete(pinID:commentID:)`)
/// **어느 핀으로 나갔는지**가 검증 대상이 됐다. 인자를 버리는 스텁만 두면 리듀서가 엉뚱한 핀을
/// 실어 보내도 테스트가 통과한다.
struct StubDeletePinComment: DeletePinCommentUseCase {
    enum Outcome: Sendable {
        case success
        case failure(DomainError)
        case cancelled
    }

    let outcome: Outcome
    let log: DeletedCommentLog?

    init(outcome: Outcome = .success, log: DeletedCommentLog? = nil) {
        self.outcome = outcome
        self.log = log
    }

    func execute(pinID: PinID, commentID: PinCommentID) async throws {
        await log?.record(pinID: pinID, commentID: commentID)
        switch outcome {
        case .success: return
        case .failure(let error): throw error
        case .cancelled: throw CancellationError()
        }
    }
}

/// 삭제 스텁이 받은 인자 기록장.
actor DeletedCommentLog {
    private(set) var entries: [(pinID: PinID, commentID: PinCommentID)] = []

    func record(pinID: PinID, commentID: PinCommentID) {
        entries.append((pinID, commentID))
    }
}

/// 테스트용 `PinComment` 생성기. 검증 대상이 아닌 필드(핀 id·작성 시각)를 케이스마다 손으로
/// 짓지 않도록 한 곳에 모은다.
enum PinCommentFixture {
    static let pinID = PinID("p1")

    static func comment(
        id: String,
        author: MemberProfile,
        body: String,
        pinID: PinID = PinCommentFixture.pinID,
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> PinComment {
        PinComment(
            id: PinCommentID(id),
            pinID: pinID,
            author: author,
            body: body,
            createdAt: createdAt
        )
    }
}
