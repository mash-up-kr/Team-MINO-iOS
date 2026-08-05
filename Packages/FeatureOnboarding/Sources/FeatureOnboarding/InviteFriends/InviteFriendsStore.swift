import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
struct InviteFriendsState: Equatable {
    // 정적 화면이라 상태 없음 — 버튼 동작(공유·초대 링크) 미연결이 확정 사항이라 화면 자체가 상태를 갖지 않는다.
}

// 뒤로가기는 Action 이 없다 — pop 은 View 의 dismiss 환경값이 담당하고 reduce 가 볼 상태가 없어서다.
enum InviteFriendsAction: Equatable {
    case tapComplete   // 건너뛰기 — 온보딩 종료 경로였으나 현재 비어 있음(아래 reduce 주석)
    case tapInvite     // 친구 초대하기 — 공유 시트 미연결(확정 사항), 상태 변화 없음
    case tapCopyLink   // 초대 링크 복사 — 링크 생성 미연결(확정 사항), 상태 변화 없음
}

/// 온보딩 종료 채널. 현재 발사하는 곳이 없다 — `complete` 를 보내던 건너뛰기가 비워졌기 때문.
/// Coordinator·`FlowFinish` 배선은 그대로 살아 있어, 종료 조건이 정해지면 `.navigate(.complete)` 한 줄로 되살아난다.
enum InviteFriendsNav: Equatable, Sendable {
    case complete
}

typealias InviteFriendsStore = Store<InviteFriendsState, InviteFriendsAction, InviteFriendsNav>

func inviteFriendsReducer() -> (inout InviteFriendsState, InviteFriendsAction) -> Effect<InviteFriendsAction, InviteFriendsNav> {
    { _, action in
        switch action {
        // 건너뛰기가 온보딩을 끝내던 유일한 경로였으나, 종료 조건이 기획에 없어 비워둔다.
        // 되살릴 때는 `.navigate(.complete)` 로 되돌리면 Coordinator 의 finish 까지 그대로 이어진다.
        case .tapComplete, .tapInvite, .tapCopyLink:
            return .none
        }
    }
}
