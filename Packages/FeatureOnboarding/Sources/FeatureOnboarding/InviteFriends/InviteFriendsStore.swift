import MVI

struct InviteFriendsState: Equatable {
    // TODO [AI_IMPL-PR4]: 친구초대 화면 상태 (PR 4 범위 — 정적 UI 예정, 이번 PR에서는 빈 상태 유지)
}

enum InviteFriendsAction: Equatable {
    case tapComplete
}

enum InviteFriendsNav: Equatable, Sendable {
    case complete
}

typealias InviteFriendsStore = Store<InviteFriendsState, InviteFriendsAction, InviteFriendsNav>

// TODO [AI_IMPL]: .tapComplete → .navigate(.complete) — 골격 완주(finish 발사) 경로는 PR 4 이후에도 유지
func inviteFriendsReducer() -> (inout InviteFriendsState, InviteFriendsAction) -> Effect<InviteFriendsAction, InviteFriendsNav> {
    fatalError("not implemented")
}
