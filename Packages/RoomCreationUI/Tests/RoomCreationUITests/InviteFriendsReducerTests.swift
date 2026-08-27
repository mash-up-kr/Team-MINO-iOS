import Core
import Domain
import Foundation
import MVITestSupport
import Testing
@testable import RoomCreationUI

@MainActor
struct InviteFriendsReducerTests {
    private static let roomId = "room-1"
    private static let code = "K7Q2MZ"
    private static let link = URL(string: "https://gguk.org/r/K7Q2MZ")!

    /// 실제 붙여넣기 보드를 건드리지 않도록 기록만 하는 클립보드를 쓴다.
    private final class CopiedURLs: @unchecked Sendable {
        private(set) var values: [URL] = []
        func append(_ url: URL) { values.append(url) }
    }

    private func makeStore(
        roomId: String? = roomId,
        result: Result<String, DomainError> = .success(code),
        copied: CopiedURLs = CopiedURLs()
    ) -> TestStore<InviteFriendsState, InviteFriendsAction, InviteFriendsNav> {
        TestStore(
            InviteFriendsState(roomId: roomId),
            reduce: inviteFriendsReducer(
                InviteFriendsDeps(
                    fetchInviteCode: StubFetchInviteCodeUseCase(result: result),
                    deeplink: DeeplinkConfiguration(scheme: "gguk", host: "gguk.org"),
                    clipboard: Clipboard { copied.append($0) }
                )
            )
        )
    }

    @Test("L2 — 닫기(tapComplete) 는 complete 를 알린다 — 목적지는 받는 쪽이 정한다")
    func tapComplete_notifiesComplete() async {
        let store = makeStore()

        await store.send(.tapComplete)
        store.receiveNavigation(.complete)

        store.finish()
    }

    @Test("L2 — 친구 초대하기는 코드를 받아 공유 링크를 연다")
    func tapInvite_opensShareSheet() async {
        let store = makeStore()

        await store.send(.tapInvite) { $0.isPreparingLink = true }
        await store.receive(.linkPrepared(Self.link, .share)) {
            $0.isPreparingLink = false
            $0.sharingLink = SharedInviteLink(url: Self.link)
        }

        store.finish()
    }

    @Test("L2 — 초대 링크 복사는 같은 코드를 클립보드에 담고 안내를 띄운다")
    func tapCopyLink_copiesToClipboard() async {
        let copied = CopiedURLs()
        let store = makeStore(copied: copied)

        await store.send(.tapCopyLink) { $0.isPreparingLink = true }
        await store.receive(.linkPrepared(Self.link, .copy)) { $0.isPreparingLink = false }
        await store.receive(.didCopyLink) { $0.didCopyLink = true }

        #expect(copied.values == [Self.link])
        #expect(store.currentState.notice == .linkCopied)
        // 복사는 화면 전환이 아니다 — 시트도 열리지 않는다.
        #expect(store.currentState.sharingLink == nil)
        store.finish()
    }

    @Test("L2 — 실패하면 안내를 띄우고 버튼을 다시 연다")
    func fetchFailure_showsNotice() async {
        let store = makeStore(result: .failure(.inviteCodeFetchFailed))

        await store.send(.tapCopyLink) { $0.isPreparingLink = true }
        await store.receive(.linkFailed(.inviteCodeFetchFailed)) {
            $0.isPreparingLink = false
            $0.error = .inviteCodeFetchFailed
        }

        #expect(store.currentState.notice == .linkFailed)
        #expect(store.currentState.isInviteEnabled)
        store.finish()
    }

    // 방 생성이 서버에 붙기 전까지 온보딩이 여기에 해당한다 — 요청을 아예 내보내지 않는다.
    @Test("L1 — 초대할 방이 없으면 버튼이 잠기고 탭해도 요청하지 않는다")
    func withoutRoom_doesNotRequest() async {
        let store = makeStore(roomId: nil)

        #expect(!store.currentState.isInviteEnabled)
        await store.send(.tapInvite)
        await store.send(.tapCopyLink)

        store.finish()
    }

    @Test("L1 — 진행 중에는 같은 요청이 겹치지 않는다")
    func whilePreparing_ignoresSecondTap() async {
        var state = InviteFriendsState(roomId: Self.roomId)
        state.isPreparingLink = true

        #expect(!state.isInviteEnabled)
    }

    @Test("L1 — 시트를 닫으면 링크가 state 에서 빠진다(다시 뜨지 않게)")
    func dismissShareSheet_clearsLink() async {
        let store = makeStore()

        await store.send(.tapInvite) { $0.isPreparingLink = true }
        await store.receive(.linkPrepared(Self.link, .share)) {
            $0.isPreparingLink = false
            $0.sharingLink = SharedInviteLink(url: Self.link)
        }
        await store.send(.dismissShareSheet) { $0.sharingLink = nil }

        store.finish()
    }

    @Test("L1 — 안내를 닫으면 복사 완료와 실패가 함께 걷힌다")
    func dismissNotice_clearsBoth() async {
        let store = makeStore()

        await store.send(.didCopyLink) { $0.didCopyLink = true }
        await store.send(.linkFailed(.unauthorized)) { $0.error = .unauthorized }
        // 실패가 복사 성공보다 앞선다 — 방금 일어난 일이 실패다.
        #expect(store.currentState.notice == .linkFailed)

        await store.send(.dismissNotice) {
            $0.didCopyLink = false
            $0.error = nil
        }
        #expect(store.currentState.notice == nil)

        store.finish()
    }
}

private struct StubFetchInviteCodeUseCase: FetchInviteCodeUseCase {
    let result: Result<String, DomainError>

    func execute(roomId: String) async throws -> String {
        try result.get()
    }
}
