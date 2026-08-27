import DesignSystem
import SwiftUI

/// 친구초대 화면의 순수 마크업. Figma `009-1 친구 초대`(node 2314:95550) ·
/// `009-2 초대링크 복사`(node 2370:67386).
///
/// Store/Coordinator 를 모른다 — 값과 콜백만 받는다.
struct InviteFriendsContent: View {
    /// `nil` 이면 상단바에 닫기(X) 버튼을 그리지 않는다 — 닫을 수 없는 진입점을 위해.
    /// 시안에 좌측 뒤로가기는 없다 — 우상단 X 하나로 튜토리얼까지 건너뛴다(스펙 2번).
    var onTapClose: (() -> Void)?
    /// 초대 버튼을 열지. 판정은 Store 몫 — 여기서는 받은 값으로만 활성/비활성을 그린다.
    var isInviteEnabled: Bool = true
    /// 하단 안내. `nil` 이면 그리지 않는다.
    var notice: InviteFriendsNotice?
    var onTapInvite: () -> Void = {}
    var onTapCopyLink: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            MHTopNavigation(onClose: onTapClose)
            titleAndDescription
            actionArea
                // 안내는 액션 영역 **바로 위**에 띄운다(시안 009-2: 스낵바 아래변 = 액션 영역 윗변).
                // 오버레이라 자리를 차지하지 않는다 — 레이아웃에 끼우면 안내가 뜰 때마다
                // 일러스트와 문구가 위로 밀린다(시안은 두 화면의 본문 위치가 같다).
                .overlay(alignment: .top) {
                    noticeSnackbar
                        // 오버레이의 "위" 기준선을 자기 아래변으로 바꿔 액션 영역 위로 올린다.
                        .alignmentGuide(.top) { $0[.bottom] }
                        .animation(.easeInOut(duration: 0.2), value: notice)
                }
        }
        .background(alignment: .bottom) { cloudBackground }
        .background(Color.mhBackgroundNormalNormal)
        .ignoresSafeArea(edges: .bottom)
    }

    /// 화면 하단을 채우는 옅은 구름 장식(Figma `BG` 375×325 — 튜토리얼 화면과 같은 에셋).
    private var cloudBackground: some View {
        Image(MHIllustration.cloudBackground)
            .resizable()
            .scaledToFill()
            .frame(height: 325)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityHidden(true)
    }

    // MARK: - Title / Illustration / Description

    private var titleAndDescription: some View {
        VStack(spacing: 0) {
            Text("친구들을 초대해볼까요?")
                .mhTypography(.title3Bold)
                .foregroundStyle(Color.mhPrimaryNormal)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                // 이 화면은 상단바에 타이틀이 없어 도달 검증을 이 문구로 한다.
                .accessibilityIdentifier("InviteFriends.title")

            // 위아래 양쪽에 둔다 — 한쪽만 두면 블록이 액션 영역까지 밀려 내려간다.
            // 시안(009-1)은 타이틀 아래 65 / 액션 영역 위 44 로 거의 가운데다.
            Spacer(minLength: 24)

            VStack(spacing: 40) {
                illustration
                Text("\"여기 어때?\"는 이제 그만\n친구가 들어오면 저장한 장소가 한눈에 모여요.\n다음 약속 장소, 여기서 같이 골라요.")
                    .mhTypography(.label1NormalRegular)
                    .foregroundStyle(Color.mhPrimaryNormal)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 24)
        }
        .padding(20)
        .frame(maxHeight: .infinity)
    }

    private var illustration: some View {
        Image(MHIllustration.inviteFriends)
            .resizable()
            .scaledToFit()
            .frame(width: 267, height: 289)
            .accessibilityHidden(true)
    }

    // MARK: - 안내(스낵바)

    // 문구·아이콘 매핑은 여기 둔다 — State 가 MHIcon 을 들면 reducer 테스트까지 DS 를 링크한다.
    @ViewBuilder private var noticeSnackbar: some View {
        if let notice {
            MHSnackbar(title: Self.message(for: notice), icon: Self.icon(for: notice))
                .padding(.horizontal, 20)
                .accessibilityIdentifier("InviteFriends.notice")
                .transition(.opacity)
        }
    }

    private static func message(for notice: InviteFriendsNotice) -> String {
        switch notice {
        case .linkCopied: "클립 보드에 초대링크가 복사되었어요"   // 시안 009-2 문구 그대로
        case .linkFailed: "초대 링크를 만들지 못했어요. 잠시 후 다시 시도해주세요."
        }
    }

    private static func icon(for notice: InviteFriendsNotice) -> MHIcon {
        switch notice {
        case .linkCopied: .checkThick
        case .linkFailed: .circleExclamationFill
        }
    }

    // MARK: - Action Area

    // NOTE: MHActionArea(.strong) 이 구조는 동일(main solid + alternative outlined, 세로 스택)하지만
    // MHAction 이 leadingIcon 을 못 받아 대체 버튼의 링크 아이콘을 표현 못 함 → MHButton 을 직접 조립.
    private var actionArea: some View {
        VStack(spacing: 8) {
            MHButton("친구 초대하기", variant: .solid, color: .primary, size: .large, action: onTapInvite)
                .mhButtonFillWidth()
                .accessibilityIdentifier("InviteFriends.invite")
            MHButton("초대 링크 복사", variant: .outlined, color: .primary, size: .large, leadingIcon: .link, action: onTapCopyLink)
                .mhButtonFillWidth()
                .accessibilityIdentifier("InviteFriends.copyLink")
        }
        .disabled(!isInviteEnabled)
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
}

#Preview("009-1 친구 초대") {
    InviteFriendsContent(onTapClose: {})
}

#Preview("009-2 초대링크 복사") {
    InviteFriendsContent(onTapClose: {}, notice: .linkCopied)
}

#Preview("링크 생성 실패") {
    InviteFriendsContent(onTapClose: {}, notice: .linkFailed)
}

// 초대할 방이 없는 상태 — 방 생성이 서버에 붙기 전까지 온보딩이 여기에 해당한다.
#Preview("초대 비활성") {
    InviteFriendsContent(onTapClose: {}, isInviteEnabled: false)
}
