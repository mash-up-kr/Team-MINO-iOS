import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
public struct InviteFriendsState: Equatable {
    // 정적 화면이라 상태 없음 — 버튼 동작(공유·초대 링크) 미연결이 확정 사항이라 화면 자체가 상태를 갖지 않는다.
    public init() {}
}

// 뒤로가기는 Action 이 없다 — pop 은 View 의 dismiss 환경값이 담당하고 reduce 가 볼 상태가 없어서다.
public enum InviteFriendsAction: Equatable {
    case tapComplete   // 건너뛰기 — 이 화면을 마쳤다는 사건만 알리고 목적지는 소비자가 정한다
    case tapInvite     // 친구 초대하기 — 공유 시트 미연결(확정 사항), 상태 변화 없음
    case tapCopyLink   // 초대 링크 복사 — 링크 생성 미연결(확정 사항), 상태 변화 없음
}

/// 목적지가 아니라 일어난 일로 이름 붙인다 — 친구초대를 마친 뒤 어디로 갈지는 진입점마다 다르다
/// (온보딩은 튜토리얼로 보내고, 방리스트에서 진입하면 목록으로 돌아간다).
public enum InviteFriendsNav: Equatable, Sendable {
    case complete
}

public typealias InviteFriendsStore = Store<InviteFriendsState, InviteFriendsAction, InviteFriendsNav>

public func inviteFriendsReducer() -> (inout InviteFriendsState, InviteFriendsAction) -> Effect<InviteFriendsAction, InviteFriendsNav> {
    { _, action in
        switch action {
        case .tapComplete:
            return .navigate(.complete)
        // 공유 시트·초대 링크 생성이 아직 없어 눌러도 아무 일도 일어나지 않는다.
        case .tapInvite, .tapCopyLink:
            return .none
        }
    }
}
