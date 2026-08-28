import Foundation
import Testing
import Domain
import MVITestSupport
@testable import FeatureArchive

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

/// ⑭ "내가 게시한 댓글에만 아이콘이 표시된다" — 소유 판정과 삭제 흐름.
@MainActor
struct PlaceDetailCommentDeleteTests {
    private static let me = MemberProfile(id: MemberID("user-0001"), nickname: "나", avatarID: 1)
    /// **닉네임은 나와 같고 식별자만 다른** 사람. 문자열 비교로 판정하면 이 사람 코멘트가 내 것이 된다.
    private static let impostor = MemberProfile(id: MemberID("user-0009"), nickname: "나", avatarID: 9)
    private static let friend = MemberProfile(id: MemberID("user-0003"), nickname: "서연", avatarID: 3)

    private static let mine = PlaceDetailComment(id: "c-mine", author: me, body: "내가 남긴 코멘트")
    private static let theirs = PlaceDetailComment(id: "c-friend", author: friend, body: "친구가 남긴 코멘트")
    private static let sameNickname = PlaceDetailComment(id: "c-impostor", author: impostor, body: "동명이인 코멘트")

    private func makeStore(
        comments: [PlaceDetailComment],
        currentMember: CurrentMemberStub.Outcome = .member(me)
    ) -> TestStore<PlaceDetailState, PlaceDetailAction, PlaceDetailNav> {
        TestStore(
            PlaceDetailState(place: PlaceDetailPlace(from: deletePin), comments: comments),
            reduce: placeDetailReducer(
                useCase: QuietFetchPinDetail(),
                fetchCurrentMember: CurrentMemberStub(outcome: currentMember),
                fetchSavedRooms: StubFetchSavedRooms(),
                pin: deletePin,
                makeCommentID: { "c-new" }
            )
        )
    }

    // MARK: - 소유 판정

    @Test("L2 — 내 코멘트에만 삭제 아이콘이 붙는다")
    func canDelete_onlyMine() async {
        let store = makeStore(comments: [Self.mine, Self.theirs])
        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoaded(Self.me)) {
            $0.currentMember = Self.me
            $0.isLoadingCurrentMember = false
        }
        #expect(store.currentState.canDelete(Self.mine))
        #expect(!store.currentState.canDelete(Self.theirs))
        store.finish()
    }

    @Test("L2 — 닉네임이 같아도 식별자가 다르면 내 것이 아니다")
    func canDelete_rejectsSameNickname() async {
        let store = makeStore(comments: [Self.mine, Self.sameNickname])
        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoaded(Self.me)) {
            $0.currentMember = Self.me
            $0.isLoadingCurrentMember = false
        }
        #expect(Self.sameNickname.author.nickname == Self.me.nickname)   // 문자열은 같다
        #expect(!store.currentState.canDelete(Self.sameNickname))        // 그래도 내 것이 아니다
        store.finish()
    }

    @Test("L2 — 현재 사용자를 못 가져오면 어떤 코멘트에도 삭제 아이콘이 안 붙는다")
    func canDelete_noneWhenViewerUnknown() async {
        let store = makeStore(comments: [Self.mine, Self.theirs], currentMember: .failure(.unknown))
        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoadFailed(.unknown)) { $0.isLoadingCurrentMember = false }
        #expect(store.currentState.currentMember == nil)
        #expect(!store.currentState.canDelete(Self.mine))
        #expect(!store.currentState.canDelete(Self.theirs))
        store.finish()
    }

    @Test("L2 — 신원 조회 취소는 실패가 아니라 결과가 필요 없어진 것이라 action 이 돌아오지 않는다")
    func loadCurrentMember_cancelled() async {
        let store = makeStore(comments: [Self.mine], currentMember: .cancelled)
        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        store.finish()
    }

    @Test("L1 — 신원을 이미 알고 있으면 다시 조회하지 않는다")
    func loadCurrentMember_isIdempotent() async {
        let store = makeStore(comments: [])
        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoaded(Self.me)) {
            $0.currentMember = Self.me
            $0.isLoadingCurrentMember = false
        }
        await store.send(.loadCurrentMember)   // 두 번째 호출은 effect 를 내지 않는다
        store.finish()
    }

    // MARK: - 삭제 흐름

    @Test("L2 — 케밥에서 삭제를 골라도 확인 모달을 거치기 전에는 지워지지 않는다")
    func tapDeleteComment_asksBeforeRemoving() async {
        let store = makeStore(comments: [Self.mine, Self.theirs])
        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoaded(Self.me)) {
            $0.currentMember = Self.me
            $0.isLoadingCurrentMember = false
        }
        await store.send(.tapCommentMenu("c-mine")) { $0.menuCommentID = "c-mine" }
        // 메뉴는 닫히고 모달이 뜬다
        await store.send(.tapDeleteComment("c-mine")) {
            $0.menuCommentID = nil
            $0.commentDeletion = PlaceDetailCommentDeletion(commentID: "c-mine")
        }
        #expect(store.currentState.comments == [Self.mine, Self.theirs])   // 아직 그대로다
        store.finish()
    }

    @Test("L2 — 확인 모달에서 삭제를 누르면 목록에서 사라진다")
    func confirmDeleteComment_removesMine() async {
        let store = makeStore(comments: [Self.mine, Self.theirs])
        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoaded(Self.me)) {
            $0.currentMember = Self.me
            $0.isLoadingCurrentMember = false
        }
        await store.send(.tapCommentMenu("c-mine")) { $0.menuCommentID = "c-mine" }
        await store.send(.tapDeleteComment("c-mine")) {
            $0.menuCommentID = nil
            $0.commentDeletion = PlaceDetailCommentDeletion(commentID: "c-mine")
        }
        await store.send(.confirmDeleteComment) {
            $0.commentDeletion = nil
            $0.comments = [Self.theirs]
        }
        store.finish()
    }

    @Test("L2 — 확인 모달에서 취소하면 코멘트가 남는다")
    func cancelDeleteComment_keepsComment() async {
        let store = makeStore(comments: [Self.mine, Self.theirs])
        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoaded(Self.me)) {
            $0.currentMember = Self.me
            $0.isLoadingCurrentMember = false
        }
        await store.send(.tapDeleteComment("c-mine")) {
            $0.commentDeletion = PlaceDetailCommentDeletion(commentID: "c-mine")
        }
        await store.send(.cancelDeleteComment) { $0.commentDeletion = nil }
        #expect(store.currentState.comments == [Self.mine, Self.theirs])
        store.finish()
    }

    @Test("L1 — 모달이 떠 있지 않은데 확인이 들어오면 아무 것도 지우지 않는다")
    func confirmDeleteComment_withoutDialog_isNoop() async {
        let store = makeStore(comments: [Self.mine, Self.theirs])
        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoaded(Self.me)) {
            $0.currentMember = Self.me
            $0.isLoadingCurrentMember = false
        }
        await store.send(.confirmDeleteComment)
        #expect(store.currentState.comments == [Self.mine, Self.theirs])
        store.finish()
    }

    @Test("L2 — 메뉴 바깥을 눌러 취소하면 코멘트는 그대로다")
    func dismissMenu_keepsComment() async {
        let store = makeStore(comments: [Self.mine, Self.theirs])
        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoaded(Self.me)) {
            $0.currentMember = Self.me
            $0.isLoadingCurrentMember = false
        }
        await store.send(.tapCommentMenu("c-mine")) { $0.menuCommentID = "c-mine" }
        await store.send(.dismissCommentMenu) { $0.menuCommentID = nil }
        #expect(store.currentState.comments == [Self.mine, Self.theirs])
        store.finish()
    }

    @Test("L1 — 남의 코멘트는 메뉴가 열리지도, 삭제되지도 않는다")
    func othersComment_isUntouchable() async {
        let store = makeStore(comments: [Self.mine, Self.theirs])
        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoaded(Self.me)) {
            $0.currentMember = Self.me
            $0.isLoadingCurrentMember = false
        }
        await store.send(.tapCommentMenu("c-friend"))       // 열리지 않는다
        await store.send(.tapDeleteComment("c-friend"))     // 모달도 뜨지 않는다
        #expect(store.currentState.menuCommentID == nil)
        #expect(store.currentState.commentDeletion == nil)
        #expect(store.currentState.comments == [Self.mine, Self.theirs])
        store.finish()
    }

    @Test("L1 — 신원을 모르는 동안에는 내 코멘트조차 지울 수 없다")
    func deleteComment_blockedWhenViewerUnknown() async {
        let store = makeStore(comments: [Self.mine])
        await store.send(.tapCommentMenu("c-mine"))
        await store.send(.tapDeleteComment("c-mine"))
        #expect(store.currentState.commentDeletion == nil)
        await store.send(.confirmDeleteComment)
        #expect(store.currentState.comments == [Self.mine])
        store.finish()
    }

    // MARK: - 등록

    @Test("L2 — 등록한 코멘트의 작성자는 지금 앱을 쓰는 사람이고, 그 줄은 바로 지울 수 있다")
    func submitComment_authoredByCurrentMember() async {
        let store = makeStore(comments: [])
        await store.send(.loadCurrentMember) { $0.isLoadingCurrentMember = true }
        await store.receive(.currentMemberLoaded(Self.me)) {
            $0.currentMember = Self.me
            $0.isLoadingCurrentMember = false
        }
        let posted = PlaceDetailComment(id: "c-new", author: Self.me, body: "좋았어요")
        await store.send(.submitComment("좋았어요")) { $0.comments = [posted] }
        #expect(store.currentState.canDelete(posted))
        store.finish()
    }

    @Test("L1 — 신원을 모르면 등록이 잠기고, 눌려도 코멘트가 생기지 않는다")
    func submitComment_blockedWhenViewerUnknown() async {
        let store = makeStore(comments: [])
        #expect(!store.currentState.canSubmitComment)
        await store.send(.submitComment("좋았어요"))
        #expect(store.currentState.comments.isEmpty)
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
