import Core
import Domain
import Foundation
import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일

/// 받아 온 초대 링크로 무엇을 할 것인가. 두 버튼이 **같은 코드**를 쓰고 마무리만 다르다.
public enum InviteLinkIntent: Equatable, Sendable {
    /// 친구 초대하기 — 시스템 공유 시트로 내보낸다.
    case share
    /// 초대 링크 복사 — 클립보드에 담는다(시안 009-2).
    case copy
}

/// 화면 아래쪽에 잠깐 뜨는 안내. 문구·아이콘은 화면이 고른다 — State 가 DesignSystem 을 알면
/// reducer 테스트까지 DS 를 링크해야 한다.
public enum InviteFriendsNotice: Equatable, Sendable {
    case linkCopied
    case linkFailed
}

/// 화면이 쓰는 의존.
public struct InviteFriendsDeps: Sendable {
    let fetchInviteCode: FetchInviteCodeUseCase
    /// 초대 링크의 스킴·호스트. **서버는 코드만 준다** — 링크 조립은 클라이언트 몫이라
    /// 읽기(`DeeplinkParser`)와 같은 설정을 써서 "우리가 만든 링크를 우리가 못 읽는" 상태를 막는다.
    let deeplink: DeeplinkConfiguration
    let clipboard: Clipboard

    public init(
        fetchInviteCode: FetchInviteCodeUseCase,
        deeplink: DeeplinkConfiguration,
        clipboard: Clipboard = .system
    ) {
        self.fetchInviteCode = fetchInviteCode
        self.deeplink = deeplink
        self.clipboard = clipboard
    }
}

/// 공유 시트에 넘길 링크. `sheet(item:)` 이 `Identifiable` 을 요구해 URL 을 감싼다.
public struct SharedInviteLink: Identifiable, Equatable, Sendable {
    public let url: URL
    public var id: URL { url }

    public init(url: URL) {
        self.url = url
    }
}

public struct InviteFriendsState: Equatable {
    /// 초대할 방.
    ///
    /// > ⚠️ **`nil` 이면 두 버튼을 잠근다.** 온보딩은 아직 서버에 방을 만들지 않아
    /// > (`POST /api/v1/rooms` 미연결, `RoomFormNav.didSubmit` 이 id 를 들고 오지 않는다)
    /// > 넘길 id 가 없다. 방 생성이 붙으면 이 옵셔널을 `String` 으로 좁힌다.
    public let roomId: String?
    /// 초대 코드를 받아오는 중. 두 버튼이 같은 요청을 쓰므로 하나로 둔다.
    public var isPreparingLink: Bool
    /// 공유 시트에 띄울 링크. `nil` 이면 시트가 닫혀 있다.
    public var sharingLink: SharedInviteLink?
    public var didCopyLink: Bool
    public var error: DomainError?

    public init(roomId: String? = nil) {
        self.roomId = roomId
        self.isPreparingLink = false
        self.sharingLink = nil
        self.didCopyLink = false
        self.error = nil
    }

    /// 초대할 방이 없으면 누를 수 없다. 받아오는 중에도 잠가 같은 요청이 겹치지 않게 한다.
    public var isInviteEnabled: Bool {
        roomId != nil && !isPreparingLink
    }

    /// 실패를 복사 성공보다 앞세운다 — 둘이 겹치는 유일한 순간은 복사 직후 실패한 재시도라
    /// 방금 일어난 일이 실패다.
    public var notice: InviteFriendsNotice? {
        if error != nil { return .linkFailed }
        return didCopyLink ? .linkCopied : nil
    }
}

// 시안(009-1)에 뒤로가기가 없다 — 상단바는 우상단 X 하나뿐이고, 그게 tapComplete 로 이어진다.
public enum InviteFriendsAction: Equatable {
    case tapComplete   // 닫기(X) — 이 화면을 마쳤다는 사건만 알리고 목적지는 소비자가 정한다
    case tapInvite
    case tapCopyLink
    case linkPrepared(URL, InviteLinkIntent)
    case linkFailed(DomainError)
    case didCopyLink
    /// 공유 시트가 닫혔다(공유했든 취소했든). 어느 쪽인지 구분하지 않는다 — 취소해도 링크는
    /// 그대로 유효하고, 화면이 할 일이 달라지지 않는다.
    case dismissShareSheet
    /// 안내를 닫는다 — 화면이 잠깐 띄웠다 스스로 거둔다.
    case dismissNotice
}

/// 목적지가 아니라 일어난 일로 이름 붙인다 — 친구초대를 마친 뒤 어디로 갈지는 진입점마다 다르다
/// (온보딩은 튜토리얼로 보내고, 방리스트에서 진입하면 목록으로 돌아간다).
public enum InviteFriendsNav: Equatable, Sendable {
    case complete
}

public typealias InviteFriendsStore = Store<InviteFriendsState, InviteFriendsAction, InviteFriendsNav>

/// 방과 의존이 어긋날 수 없게 Store 를 한 번에 만든다.
///
/// ```swift
/// let store = makeInviteFriendsStore(roomId: room.id, deps: .init(...))
/// store.observeNavigation { [weak self] in self?.handle($0) }   // 필수
/// ```
@MainActor
public func makeInviteFriendsStore(roomId: String?, deps: InviteFriendsDeps) -> InviteFriendsStore {
    InviteFriendsStore(InviteFriendsState(roomId: roomId), reduce: inviteFriendsReducer(deps))
}

public func inviteFriendsReducer(
    _ deps: InviteFriendsDeps
) -> (inout InviteFriendsState, InviteFriendsAction) -> Effect<InviteFriendsAction, InviteFriendsNav> {
    { state, action in
        switch action {
        case .tapComplete:
            return .navigate(.complete)

        case .tapInvite:
            return prepareLink(&state, deps: deps, intent: .share)

        case .tapCopyLink:
            return prepareLink(&state, deps: deps, intent: .copy)

        case .linkPrepared(let url, let intent):
            state.isPreparingLink = false
            switch intent {
            case .share:
                state.sharingLink = SharedInviteLink(url: url)
                return .none
            case .copy:
                // 복사는 화면 밖(시스템 보드)을 건드리므로 reduce 가 직접 하지 않고 Effect 로 미룬다.
                return .run { send in
                    deps.clipboard.copy(url)
                    send(.didCopyLink)
                }
            }

        case .didCopyLink:
            state.didCopyLink = true
            return .none

        case .linkFailed(let error):
            state.isPreparingLink = false
            state.error = error
            return .none

        case .dismissShareSheet:
            state.sharingLink = nil
            return .none

        case .dismissNotice:
            state.didCopyLink = false
            state.error = nil
            return .none
        }
    }
}

/// 두 버튼이 같은 일을 한다 — 코드를 받아 링크로 조립하고, 마무리만 `intent` 로 갈린다.
private func prepareLink(
    _ state: inout InviteFriendsState,
    deps: InviteFriendsDeps,
    intent: InviteLinkIntent
) -> Effect<InviteFriendsAction, InviteFriendsNav> {
    // 뷰의 .disabled 는 UI 레이어 방어라 뷰가 바뀌면 뚫린다 — 조건은 여기서도 지킨다.
    guard let roomId = state.roomId, !state.isPreparingLink else { return .none }
    state.isPreparingLink = true
    state.error = nil
    state.didCopyLink = false

    return .run { send in
        do {
            let code = try await deps.fetchInviteCode.execute(roomId: roomId)
            guard let url = DeeplinkBuilder(configuration: deps.deeplink)
                .webURL(for: .invite(code: code)) else {
                // 코드를 받고도 링크를 못 만든 경우 — 서버 코드 형식이 링크 문법을 깨뜨렸다는 뜻이라
                // 사용자에겐 실패와 다를 게 없다. 조용히 넘기면 버튼이 고장 난 걸로 보인다.
                send(.linkFailed(.inviteCodeFetchFailed))
                return
            }
            send(.linkPrepared(url, intent))
        } catch is CancellationError {
            return   // 취소는 결과가 없는 것이지 실패가 아니다
        } catch {
            send(.linkFailed(error as? DomainError ?? .inviteCodeFetchFailed))
        }
    }
}
