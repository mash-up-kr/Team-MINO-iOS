import MVI

struct InviteFriendsState: Equatable {
    // 골격 PR 이라 상태가 없다. 친구초대 화면 PR 에서 필요해지면 채운다.
}

enum InviteFriendsAction: Equatable {
    case tapComplete
}

enum InviteFriendsNav: Equatable, Sendable {
    case complete
}

typealias InviteFriendsStore = Store<InviteFriendsState, InviteFriendsAction, InviteFriendsNav>

// 골격 완주(finish 발사) 경로는 PR 4 이후에도 유지
func inviteFriendsReducer() -> (inout InviteFriendsState, InviteFriendsAction) -> Effect<InviteFriendsAction, InviteFriendsNav> {
    { _, action in
        switch action {
        case .tapComplete:
            return .navigate(.complete)
        }
    }
}
