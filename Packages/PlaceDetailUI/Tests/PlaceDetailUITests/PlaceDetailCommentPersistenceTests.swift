import Foundation
import Testing
import Domain
import MVITestSupport
@testable import PlaceDetailUI

private let persistPin = PinFixture.pin(
    id: PinID("p1"),
    roomID: "r1",
    category: .worthVisiting,
    title: "레이어스튜디오 10",
    address: "서울 성동구 상원4길 10",
    createdAt: Date(timeIntervalSince1970: 1_700_000_000)
)

/// 출처·저장된 방은 이 스위트의 관심사가 아니라 조용히 끝낸다.
private struct QuietFetchPinDetail: FetchPinDetailUseCase {
    func execute(pinID: PinID) async throws -> PinDetail {
        PinDetail(pin: persistPin, sourceURL: nil)
    }
}

/// 현위치 조회도 이 스위트의 관심사가 아니다 — 부르지 않는다.
private struct QuietCurrentLocation: CurrentLocationUseCase {
    func execute() async -> CurrentLocationResult { .unavailable }
}

// 표본은 타입 밖에 둔다 — 스위트가 `@MainActor` 라 static 프로퍼티도 격리되고, 기본 인자의
// `@Sendable` 클로저에서는 격리된 값을 읽을 수 없다.
private let me = MemberProfile(id: MemberID("user-0001"), nickname: "나", avatarColor: .red)
private let friend = MemberProfile(id: MemberID("user-0003"), nickname: "서연", avatarColor: .orange)

private let storedComments = [
    PinCommentFixture.comment(id: "c1", author: friend, body: "웨이팅 있어서 오픈런했어요"),
    PinCommentFixture.comment(id: "c2", author: me, body: "저도 다녀왔어요"),
]

/// #165 — 코멘트가 화면 상태가 아니라 **저장소**에 남는가. 조회로 되받아오는 경로와
/// 등록이 응답을 기다렸다 반영되는 경로를 본다.
@MainActor
struct PlaceDetailCommentPersistenceTests {
    private func makeStore(
        comments: StubFetchPinComments.Outcome = .comments(storedComments),
        post: StubPostPinComment.Outcome = .posted({ body in
            PinCommentFixture.comment(id: "c-new", author: me, body: body)
        }),
        state: PlaceDetailState? = nil
    ) -> TestStore<PlaceDetailState, PlaceDetailAction, PlaceDetailNav> {
        TestStore(
            state ?? PlaceDetailState(
                place: PlaceDetailPlace(from: persistPin, label: nil),
                currentMember: me
            ),
            reduce: placeDetailReducer(
                useCase: QuietFetchPinDetail(),
                fetchCurrentMember: CurrentMemberStub(outcome: .member(me)),
                fetchSavedRooms: StubFetchSavedRooms(),
                fetchComments: StubFetchPinComments(outcome: comments),
                postComment: StubPostPinComment(outcome: post),
                deleteComment: StubDeletePinComment(),
                currentLocation: QuietCurrentLocation(),
                recordPinAccess: SpyRecordPinAccess(),
                pin: persistPin
            )
        )
    }

    // MARK: - 조회

    @Test("L2 — 진입하면 저장소에 남아 있던 코멘트를 받아 그린다 (#165 의 본체)")
    func loadComments_showsStored() async {
        let store = makeStore()

        await store.send(.loadComments) { $0.isLoadingComments = true }
        await store.receive(.commentsLoaded(storedComments)) {
            $0.comments = storedComments
            $0.isLoadingComments = false
            $0.hasLoadedComments = true
        }

        // 화면이 지어낸 게 아니라 받아 온 목록이라, 나갔다 들어와 같은 조회를 하면 같은 줄이 온다.
        #expect(store.currentState.comments == storedComments)
        store.finish()
    }

    @Test("L2 — 조회에 실패해도 이미 그려 둔 목록을 지우지 않는다")
    func loadComments_failureKeepsExisting() async {
        var state = PlaceDetailState(place: PlaceDetailPlace(from: persistPin, label: nil), currentMember: me)
        state.comments = storedComments
        let store = makeStore(comments: .failure(.unknown), state: state)

        await store.send(.loadComments) { $0.isLoadingComments = true }
        await store.receive(.commentsLoadFailed(.unknown)) { $0.isLoadingComments = false }

        #expect(store.currentState.comments == storedComments)
        store.finish()
    }

    @Test("L2 — 취소는 실패가 아니라 결과가 필요 없어진 것이라 action 이 돌아오지 않는다")
    func loadComments_cancelled() async {
        let store = makeStore(comments: .cancelled)

        await store.send(.loadComments) { $0.isLoadingComments = true }

        store.finish()
    }

    @Test("L1 — 조회가 진행 중이면 다시 받아도 중복 조회하지 않는다")
    func loadComments_isIdempotentWhileLoading() async {
        let store = makeStore(comments: .cancelled)

        await store.send(.loadComments) { $0.isLoadingComments = true }
        await store.send(.loadComments)

        store.finish()
    }

    @Test("L2 — 조회가 끝나기 전에는 '아직 코멘트가 없어요' 를 띄우지 않는다")
    func emptyStateWaitsForLoad() async {
        let store = makeStore(comments: .comments([]))

        // 진입 첫 프레임: 목록은 비었지만 아직 물어보지도 않았다 — 빈 상태를 띄우면 거짓말이다.
        #expect(store.currentState.comments.isEmpty)
        #expect(!store.currentState.showsCommentEmptyState)

        await store.send(.loadComments) { $0.isLoadingComments = true }
        #expect(!store.currentState.showsCommentEmptyState)   // 물어보는 중에도 아직

        await store.receive(.commentsLoaded([])) {
            $0.isLoadingComments = false
            $0.hasLoadedComments = true
        }
        #expect(store.currentState.showsCommentEmptyState)    // 물어봤더니 없더라 — 이제 띄운다

        store.finish()
    }

    @Test("L2 — 조회에 실패하면 빈 상태도 띄우지 않는다: 없는 것과 모르는 것은 다르다")
    func emptyStateStaysHiddenAfterFailure() async {
        let store = makeStore(comments: .failure(.unknown))

        await store.send(.loadComments) { $0.isLoadingComments = true }
        await store.receive(.commentsLoadFailed(.unknown)) { $0.isLoadingComments = false }

        #expect(store.currentState.comments.isEmpty)
        #expect(!store.currentState.showsCommentEmptyState)
        store.finish()
    }

    // MARK: - 등록 (응답 후 갱신)

    @Test("L2 — 등록은 응답을 받은 뒤 목록에 붙는다. 그 사이 등록 버튼은 잠긴다")
    func submitComment_appendsAfterResponse() async {
        let store = makeStore()
        let posted = PinCommentFixture.comment(id: "c-new", author: me, body: "좋았어요")

        await store.send(.submitComment("좋았어요")) { $0.isSubmittingComment = true }
        #expect(!store.currentState.canSubmitComment)   // 응답 전에는 다시 못 누른다
        #expect(store.currentState.comments.isEmpty)    // 낙관적으로 미리 붙이지 않는다
        await store.receive(.commentPosted(posted)) {
            $0.isSubmittingComment = false
            $0.comments = [posted]
        }
        #expect(store.currentState.canDelete(posted))   // 내가 쓴 줄이라 바로 지울 수 있다

        store.finish()
    }

    @Test("L2 — 앞뒤 공백을 잘라 보내고, 공백뿐이면 요청 자체를 내지 않는다")
    func submitComment_trimsAndIgnoresBlank() async {
        let store = makeStore()
        let posted = PinCommentFixture.comment(id: "c-new", author: me, body: "좋았어요")

        await store.send(.submitComment("  좋았어요  ")) { $0.isSubmittingComment = true }
        // 스텁이 받은 본문을 그대로 실어 돌려준다 — 다듬지 않고 보냈다면 이 단언이 깨진다.
        await store.receive(.commentPosted(posted)) {
            $0.isSubmittingComment = false
            $0.comments = [posted]
        }
        await store.send(.submitComment("   "))   // effect 없음

        store.finish()
    }

    @Test("L1 — 응답을 기다리는 동안 또 눌러도 요청을 두 번 보내지 않는다")
    func submitComment_ignoresSecondTap() async {
        let store = makeStore()
        let posted = PinCommentFixture.comment(id: "c-new", author: me, body: "좋았어요")

        await store.send(.submitComment("좋았어요")) { $0.isSubmittingComment = true }
        await store.send(.submitComment("좋았어요"))   // effect 없음
        await store.receive(.commentPosted(posted)) {
            $0.isSubmittingComment = false
            $0.comments = [posted]
        }

        store.finish()
    }

    @Test("L1 — 같은 코멘트가 두 번 돌아와도 줄이 겹쳐 늘지 않는다")
    func commentPosted_isIdempotent() async {
        let store = makeStore()
        let posted = PinCommentFixture.comment(id: "c-new", author: me, body: "좋았어요")

        await store.send(.commentPosted(posted)) { $0.comments = [posted] }
        await store.send(.commentPosted(posted))   // 변화 없음

        #expect(store.currentState.comments == [posted])
        store.finish()
    }

    @Test("L2 — 등록에 실패하면 목록에 아무것도 붙지 않고 등록 버튼이 풀린다")
    func submitComment_failure() async {
        let store = makeStore(post: .failure(.unknown))

        await store.send(.submitComment("좋았어요")) { $0.isSubmittingComment = true }
        await store.receive(.commentPostFailed(.unknown)) { $0.isSubmittingComment = false }

        #expect(store.currentState.comments.isEmpty)
        #expect(store.currentState.canSubmitComment)
        store.finish()
    }

    @Test("L2 — 등록 취소는 실패가 아니라 결과가 필요 없어진 것이라 action 이 돌아오지 않는다")
    func submitComment_cancelled() async {
        let store = makeStore(post: .cancelled)

        await store.send(.submitComment("좋았어요")) { $0.isSubmittingComment = true }

        store.finish()
    }

    @Test("L1 — 신원을 모르면 등록이 잠기고, 눌려도 요청이 나가지 않는다")
    func submitComment_blockedWhenViewerUnknown() async {
        let store = makeStore(state: PlaceDetailState(place: PlaceDetailPlace(from: persistPin, label: nil)))

        #expect(!store.currentState.canSubmitComment)
        await store.send(.submitComment("좋았어요"))

        #expect(store.currentState.comments.isEmpty)
        store.finish()
    }
}
