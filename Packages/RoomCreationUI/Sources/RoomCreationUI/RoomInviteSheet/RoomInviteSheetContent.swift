import DesignSystem
import SwiftUI

/// 친구 초대 시트에 그릴 참여자 한 명. Figma `2542:125843` ③.
///
/// 도메인 `RoomMember` 를 그대로 받지 않고 표시 모델로 좁힌다 — 아바타 색을 그림으로 옮기는
/// `AvatarPalette` 는 `ProfileSetupUI` 에 있고 이 패키지는 그걸 의존하지 않는다. `*UI` 는 값과
/// 콜백만 받는다는 규약(``InviteFriendsContent``)대로 **그림을 밖에서 주입**받아 의존을 늘리지 않는다.
public struct RoomInviteMember: Identifiable, Equatable {
    public let id: String
    public let name: String
    /// `nil` 이면 ``MHAvatar`` 가 빈 원을 그린다 — 아바타를 모르는 멤버 자리다.
    public let avatar: Image?

    public init(id: String, name: String, avatar: Image?) {
        self.id = id
        self.name = name
        self.avatar = avatar
    }
}

/// 친구 초대 시트의 본문 — 참여자 목록 + 액션 영역. Figma `2542:125843` ③④⑤.
///
/// 그래버·헤더는 ``RoomInviteSheetView`` 가 Store 밖에서 그린다(생성 전에도 닫을 수 있게).
struct RoomInviteSheetContent: View {
    let members: [RoomInviteMember]
    let state: InviteFriendsState
    let send: (InviteFriendsAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            memberList
            actionArea
        }
    }

    // MARK: - 참여자 목록 (③)

    // 네이티브 `.sheet` 안이라 `MHBottomSheetScrollView` 가 아니라 일반 `ScrollView` 다
    // (그건 `MHBottomSheet` 의 detent 드래그와 맞물리는 컴포넌트다 — `RoomShareSheet` 와 같은 판단).
    private var memberList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(members) { member in
                    row(member)
                }
            }
        }
        .frame(height: RoomInviteSheetMetrics.memberScrollHeight(count: members.count))
        .padding(.top, RoomInviteSheetMetrics.memberListTopPadding)
        .padding(.horizontal, 20)
        .accessibilityIdentifier("RoomInvite.memberList")
    }

    // 아바타 + 닉네임 2요소 행은 DS 에 없다(`MHComment` 는 본문 `comment` 가 필수, `MHAvatarGroup`·
    // `MHAvatarStack` 은 가로 겹침 pill 이라 이름 슬롯이 없다). 아바타만 `MHAvatar` 로 맞추고
    // 행 래퍼는 여기서 조립한다.
    private func row(_ member: RoomInviteMember) -> some View {
        HStack(spacing: 12) {
            MHAvatar(member.avatar, size: 48)
            Text(member.name)
                .mhTypography(.label1NormalMedium)
                .foregroundStyle(Color.mhLabelAlternative)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    // MARK: - 액션 영역 (④⑤)

    private var actionArea: some View {
        MHActionArea(
            variant: .strong,
            main: .init("초대하기", isEnabled: state.isInviteEnabled) { send(.tapInvite) },
            alternative: .init(
                "링크 복사하기",
                isEnabled: state.isInviteEnabled,
                leadingIcon: .link
            ) { send(.tapCopyLink) },
            // 목록이 버튼 뒤로 지나가므로 상단 20pt 페이드가 있는 배경을 깐다.
            sticky: true,
            // 시트가 이미 홈 인디케이터 높이를 확보한다 — 켜 두면 34pt 가 이중으로 잡혀 시트가
            // 시안(424)보다 그만큼 커진다(``RoomShareSheet`` 와 같은 이유).
            safeArea: false
        )
        // 안내는 액션 영역 **바로 위**에 띄운다. 오버레이라 자리를 차지하지 않아 안내가 뜰 때
        // 목록이 밀리지 않는다(``InviteFriendsContent`` 와 같은 방식).
        //
        // 껍데기(`ArchiveShellView`)의 화면 바닥 토스트를 쓸 수 없다 — 이 시트가 그 위를 덮는다.
        .overlay(alignment: .top) {
            noticeSnackbar
                // 오버레이의 "위" 기준선을 자기 아래변으로 바꿔 액션 영역 위로 올린다.
                .alignmentGuide(.top) { $0[.bottom] }
                .animation(.easeInOut(duration: 0.2), value: state.notice)
        }
    }

    // MARK: - 안내(스낵바)

    // 문구·아이콘 매핑을 View 에 두는 이유는 ``InviteFriendsContent`` 와 같다 — State 가 `MHIcon` 을
    // 들면 reducer 테스트까지 DesignSystem 을 링크해야 한다.
    @ViewBuilder private var noticeSnackbar: some View {
        if let notice = state.notice {
            MHSnackbar(title: Self.message(for: notice), icon: Self.icon(for: notice))
                .padding(.horizontal, 20)
                .accessibilityIdentifier("RoomInvite.notice")
                .transition(.opacity)
        }
    }

    // 온보딩(009-2)과 문구가 다르다 — 004-4-2 ⑤ 가 "초대 링크를 복사했어요" 로 못박았다.
    // 같은 Store 를 쓰지만 화면마다 자기 시안 문구를 쓴다.
    private static func message(for notice: InviteFriendsNotice) -> String {
        switch notice {
        case .linkCopied: "초대 링크를 복사했어요"
        case .linkFailed: "초대 링크를 만들지 못했어요. 잠시 후 다시 시도해주세요."
        case .sessionExpired: SaveErrorText.sessionExpired
        }
    }

    private static func icon(for notice: InviteFriendsNotice) -> MHIcon {
        switch notice {
        case .linkCopied: .checkThick
        case .linkFailed, .sessionExpired: .circleExclamationFill
        }
    }
}

// MARK: - 마크업 프리뷰

private extension [RoomInviteMember] {
    /// 시안(③)대로 3번째 행이 잘려 보이는 인원 수.
    ///
    /// `static let` 으로 둘 수 없다 — ``RoomInviteMember`` 가 `Image` 를 물어 `Sendable` 이 아니라
    /// 전역 저장 프로퍼티가 Swift 6 에서 막힌다. 프리뷰용이라 매번 만들어도 무리가 없다.
    static var sample: [RoomInviteMember] {
        (1...5).map { RoomInviteMember(id: "u\($0)", name: "이름\($0)", avatar: nil) }
    }
}

#Preview("004-4-2 친구 초대") {
    RoomInviteSheetContent(members: .sample, state: InviteFriendsState(roomId: "r1"), send: { _ in })
        .frame(height: RoomInviteSheetMetrics.detentHeight(memberCount: 5))
}

#Preview("링크 복사 완료") {
    var state = InviteFriendsState(roomId: "r1")
    state.didCopyLink = true
    return RoomInviteSheetContent(members: .sample, state: state, send: { _ in })
        .frame(height: RoomInviteSheetMetrics.detentHeight(memberCount: 5))
}

// 참여자가 상한(176)을 안 채우는 방 — 목록만 짧아지고 액션 영역이 따라 올라온다.
#Preview("참여자 1명") {
    RoomInviteSheetContent(
        members: [RoomInviteMember(id: "u1", name: "나", avatar: nil)],
        state: InviteFriendsState(roomId: "r1"),
        send: { _ in }
    )
}

// 방 id 가 비어 오면 두 버튼이 잠긴다(잘못된 방으로 초대하는 대신 아무 요청도 보내지 않는다).
#Preview("초대 비활성") {
    RoomInviteSheetContent(members: .sample, state: InviteFriendsState(), send: { _ in })
        .frame(height: RoomInviteSheetMetrics.detentHeight(memberCount: 5))
}
