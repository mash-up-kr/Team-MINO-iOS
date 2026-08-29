import Foundation
import Testing
import Domain
import MVITestSupport
@testable import PlaceDetailUI

private let deletePin = PinFixture.pin(
    id: PinID("p1"),
    roomID: "r1",
    category: .worthVisiting,
    title: "레이어스튜디오 10",
    address: "서울 성동구 상원4길 10",
    createdAt: Date(timeIntervalSince1970: 1_700_000_000)
)

/// 출처 조회는 이 스위트의 관심사가 아니라 항상 같은 값으로 즉답한다.
private struct QuietFetchPinDetail: FetchPinDetailUseCase {
    func execute(pinID: PinID) async throws -> PinDetail {
        PinDetail(pin: deletePin, sourceURL: nil)
    }
}

/// 현위치 조회는 이 스위트의 관심사가 아니다 — 부르지 않는다.
private struct QuietCurrentLocation: CurrentLocationUseCase {
    func execute() async -> CurrentLocationResult { .unavailable }
}

// 표본은 타입 밖에 둔다 — 스위트가 `@MainActor` 라 static 프로퍼티도 격리되고, 스텁의
// `@Sendable` 클로저에서는 격리된 값을 읽을 수 없다.
private let me = MemberProfile(id: MemberID("user-0001"), nickname: "나", avatarColor: .red)
/// **닉네임은 나와 같고 식별자만 다른** 사람. 문자열 비교로 판정하면 이 사람 코멘트가 내 것이 된다.
private let impostor = MemberProfile(id: MemberID("user-0009"), nickname: "나", avatarColor: .blue)
private let friend = MemberProfile(id: MemberID("user-0003"), nickname: "서연", avatarColor: .orange)

private let mine = PinCommentFixture.comment(id: "c-mine", author: me, body: "내가 남긴 코멘트")
private let theirs = PinCommentFixture.comment(id: "c-friend", author: friend, body: "친구가 남긴 코멘트")
private let sameNickname = PinCommentFixture.comment(
    id: "c-impostor", author: impostor, body: "동명이인 코멘트"
)

/// ⑭ "내가 게시한 댓글에만 아이콘이 표시된다" — 소유 판정과 삭제 흐름.
@MainActor
struct PlaceDetailCommentDeleteTests {
    private func makeStore(
        comments: [PinComment],
        currentMember: CurrentMemberStub.Outcome = .member(me),
        delete: StubDeletePinComment.Outcome = .success
    ) -> TestStore<PlaceDetailState, PlaceDetailAction, PlaceDetailNav> {
        TestStore(
            PlaceDetailState(place: PlaceDetailPlace(from: deletePin, label: nil), comments: comments),
            reduce: placeDetailReducer(
                useCase: QuietFetchPinDetail(),
                fetchCurrentMember: CurrentMemberStub(outcome: currentMember),
                fetchSavedRooms: StubFetchSavedRooms(),
                fetchComments: StubFetchPinComments(outcome: .comments(comments)),
                postComment: StubPostPinComment(
                    outcome: .posted { PinCommentFixture.comment(id: "c-new", author: me, body: $0) }
                ),
                deleteComment: StubDeletePinComment(outcome: delete),
                currentLocation: QuietCurrentLocation(),
                pin: deletePin
            )
        )
    }

    /// 신원 조회를 끝내 놓는다 — 소유 판정이 걸리려면 먼저 내가 누구인지 알아야 한다.
    private func loadMe(_ store: TestStore<PlaceDetailState, PlaceDetailAction, PlaceDetailNav>) async {
        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoaded(me)) {
            $0.currentMember = me
            $0.isLoadingCurrentMember = false
        }
    }

    // MARK: - 소유 판정

    @Test("L2 — 내 코멘트에만 삭제 아이콘이 붙는다")
    func canDelete_onlyMine() async {
        let store = makeStore(comments: [mine, theirs])
        await loadMe(store)
        #expect(store.currentState.canDelete(mine))
        #expect(!store.currentState.canDelete(theirs))
        store.finish()
    }

    @Test("L2 — 닉네임이 같아도 식별자가 다르면 내 것이 아니다")
    func canDelete_rejectsSameNickname() async {
        let store = makeStore(comments: [mine, sameNickname])
        await loadMe(store)
        #expect(sameNickname.author.nickname == me.nickname)   // 문자열은 같다
        #expect(!store.currentState.canDelete(sameNickname))        // 그래도 내 것이 아니다
        store.finish()
    }

    @Test("L2 — 현재 사용자를 못 가져오면 어떤 코멘트에도 삭제 아이콘이 안 붙는다")
    func canDelete_noneWhenViewerUnknown() async {
        let store = makeStore(comments: [mine, theirs], currentMember: .failure(.unknown))
        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoadFailed(.unknown)) { $0.isLoadingCurrentMember = false }
        #expect(store.currentState.currentMember == nil)
        #expect(!store.currentState.canDelete(mine))
        #expect(!store.currentState.canDelete(theirs))
        store.finish()
    }

    @Test("L2 — 신원 조회 취소는 실패가 아니라 결과가 필요 없어진 것이라 action 이 돌아오지 않는다")
    func loadCurrentMember_cancelled() async {
        let store = makeStore(comments: [mine], currentMember: .cancelled)
        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        store.finish()
    }

    @Test("L1 — 신원을 이미 알고 있으면 다시 조회하지 않는다")
    func loadCurrentMember_isIdempotent() async {
        let store = makeStore(comments: [])
        await loadMe(store)
        await store.send(.loadCurrentMember)   // 두 번째 호출은 effect 를 내지 않는다
        store.finish()
    }

    // MARK: - 삭제 흐름

    @Test("L2 — 케밥에서 삭제를 골라도 확인 모달을 거치기 전에는 지워지지 않는다")
    func tapDeleteComment_asksBeforeRemoving() async {
        let store = makeStore(comments: [mine, theirs])
        await loadMe(store)
        await store.send(.tapCommentMenu(mine.id)) { $0.menuCommentID = mine.id }
        // 메뉴는 닫히고 모달이 뜬다
        await store.send(.tapDeleteComment(mine.id)) {
            $0.menuCommentID = nil
            $0.commentDeletion = PlaceDetailCommentDeletion(commentID: mine.id)
        }
        #expect(store.currentState.comments == [mine, theirs])   // 아직 그대로다
        store.finish()
    }

    @Test("L2 — 확인 모달에서 삭제를 누르면 서버 응답을 받은 뒤 목록에서 사라진다")
    func confirmDeleteComment_removesMine() async {
        let store = makeStore(comments: [mine, theirs])
        await loadMe(store)
        await store.send(.tapDeleteComment(mine.id)) {
            $0.commentDeletion = PlaceDetailCommentDeletion(commentID: mine.id)
        }
        // 응답 전에는 모달이 떠 있고 두 버튼이 잠긴다 — 연타로 두 번 지우지 않는다.
        await store.send(.confirmDeleteComment) {
            $0.commentDeletion = PlaceDetailCommentDeletion(commentID: mine.id, isSubmitting: true)
        }
        #expect(store.currentState.comments == [mine, theirs])
        await store.receive(.commentDeleted(mine.id)) {
            $0.commentDeletion = nil
            $0.comments = [theirs]
        }
        store.finish()
    }

    @Test("L2 — 삭제에 실패하면 모달만 닫히고 코멘트는 그 자리에 남는다")
    func confirmDeleteComment_failureKeepsComment() async {
        let store = makeStore(comments: [mine, theirs], delete: .failure(.unknown))
        await loadMe(store)
        await store.send(.tapDeleteComment(mine.id)) {
            $0.commentDeletion = PlaceDetailCommentDeletion(commentID: mine.id)
        }
        await store.send(.confirmDeleteComment) {
            $0.commentDeletion = PlaceDetailCommentDeletion(commentID: mine.id, isSubmitting: true)
        }
        await store.receive(.commentDeleteFailed(.unknown)) { $0.commentDeletion = nil }
        #expect(store.currentState.comments == [mine, theirs])
        store.finish()
    }

    @Test("L2 — 삭제 취소는 실패가 아니라 결과가 필요 없어진 것이라 action 이 돌아오지 않는다")
    func confirmDeleteComment_cancelled() async {
        let store = makeStore(comments: [mine], delete: .cancelled)
        await loadMe(store)
        await store.send(.tapDeleteComment(mine.id)) {
            $0.commentDeletion = PlaceDetailCommentDeletion(commentID: mine.id)
        }
        await store.send(.confirmDeleteComment) {
            $0.commentDeletion = PlaceDetailCommentDeletion(commentID: mine.id, isSubmitting: true)
        }
        store.finish()
    }

    @Test("L1 — 응답을 기다리는 동안 확인이 또 들어와도 요청을 두 번 보내지 않는다")
    func confirmDeleteComment_ignoresSecondConfirm() async {
        let store = makeStore(comments: [mine])
        await loadMe(store)
        await store.send(.tapDeleteComment(mine.id)) {
            $0.commentDeletion = PlaceDetailCommentDeletion(commentID: mine.id)
        }
        await store.send(.confirmDeleteComment) {
            $0.commentDeletion = PlaceDetailCommentDeletion(commentID: mine.id, isSubmitting: true)
        }
        await store.send(.confirmDeleteComment)   // effect 없음
        await store.receive(.commentDeleted(mine.id)) {
            $0.commentDeletion = nil
            $0.comments = []
        }
        store.finish()
    }

    @Test("L2 — 확인 모달에서 취소하면 코멘트가 남는다")
    func cancelDeleteComment_keepsComment() async {
        let store = makeStore(comments: [mine, theirs])
        await loadMe(store)
        await store.send(.tapDeleteComment(mine.id)) {
            $0.commentDeletion = PlaceDetailCommentDeletion(commentID: mine.id)
        }
        await store.send(.cancelDeleteComment) { $0.commentDeletion = nil }
        #expect(store.currentState.comments == [mine, theirs])
        store.finish()
    }

    @Test("L1 — 모달이 떠 있지 않은데 확인이 들어오면 아무 것도 지우지 않는다")
    func confirmDeleteComment_withoutDialog_isNoop() async {
        let store = makeStore(comments: [mine, theirs])
        await loadMe(store)
        await store.send(.confirmDeleteComment)
        #expect(store.currentState.comments == [mine, theirs])
        store.finish()
    }

    @Test("L2 — 메뉴 바깥을 눌러 취소하면 코멘트는 그대로다")
    func dismissMenu_keepsComment() async {
        let store = makeStore(comments: [mine, theirs])
        await loadMe(store)
        await store.send(.tapCommentMenu(mine.id)) { $0.menuCommentID = mine.id }
        await store.send(.dismissCommentMenu) { $0.menuCommentID = nil }
        #expect(store.currentState.comments == [mine, theirs])
        store.finish()
    }

    @Test("L1 — 남의 코멘트는 메뉴가 열리지도, 삭제 요청이 나가지도 않는다")
    func othersComment_isUntouchable() async {
        let store = makeStore(comments: [mine, theirs])
        await loadMe(store)
        await store.send(.tapCommentMenu(theirs.id))       // 열리지 않는다
        await store.send(.tapDeleteComment(theirs.id))     // 모달도 뜨지 않는다
        #expect(store.currentState.menuCommentID == nil)
        #expect(store.currentState.commentDeletion == nil)
        #expect(store.currentState.comments == [mine, theirs])
        store.finish()
    }

    @Test("L1 — 신원을 모르는 동안에는 내 코멘트조차 지울 수 없다")
    func deleteComment_blockedWhenViewerUnknown() async {
        let store = makeStore(comments: [mine])
        await store.send(.tapCommentMenu(mine.id))
        await store.send(.tapDeleteComment(mine.id))
        #expect(store.currentState.commentDeletion == nil)
        await store.send(.confirmDeleteComment)
        #expect(store.currentState.comments == [mine])
        store.finish()
    }
}

/// 현재 사용자 조회를 즉답시키는 스텁 — 성공·실패·취소를 골라 재생한다.
struct CurrentMemberStub: CurrentMemberUseCase {
    enum Outcome: Sendable {
        case member(MemberProfile)
        case failure(DomainError)
        case cancelled
    }

    let outcome: Outcome

    func execute() async throws -> MemberProfile {
        switch outcome {
        case .member(let profile): return profile
        case .failure(let error): throw error
        case .cancelled: throw CancellationError()
        }
    }
}
