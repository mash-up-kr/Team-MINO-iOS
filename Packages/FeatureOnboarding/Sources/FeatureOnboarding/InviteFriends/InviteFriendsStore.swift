import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
struct InviteFriendsState: Equatable {
    // 정적 화면이라 상태 없음 — 버튼 동작(공유·초대 링크) 미연결이 확정 사항이라 화면 자체가 상태를 갖지 않는다.
}

enum InviteFriendsAction: Equatable {
    case tapComplete   // 건너뛰기 — 온보딩 플로우 완료(사실상 유일한 완료 경로)
    case tapBack       // 뒤로가기 — 실제 pop 은 View 의 dismiss 환경값이 담당, reduce 는 상태 변화 없음
    case tapInvite     // 친구 초대하기 — 공유 시트 미연결(확정 사항), 상태 변화 없음
    case tapCopyLink   // 초대 링크 복사 — 링크 생성 미연결(확정 사항), 상태 변화 없음
}

enum InviteFriendsNav: Equatable, Sendable {
    case complete
}

typealias InviteFriendsStore = Store<InviteFriendsState, InviteFriendsAction, InviteFriendsNav>

func inviteFriendsReducer() -> (inout InviteFriendsState, InviteFriendsAction) -> Effect<InviteFriendsAction, InviteFriendsNav> {
    { _, action in
        switch action {
        case .tapComplete:
            return .navigate(.complete)
        case .tapBack, .tapInvite, .tapCopyLink:
            return .none
        }
    }
}
