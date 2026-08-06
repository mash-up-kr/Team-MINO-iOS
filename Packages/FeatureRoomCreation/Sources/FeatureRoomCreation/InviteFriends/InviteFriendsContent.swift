import DesignSystem
import SwiftUI

/// 친구초대 화면의 순수 마크업. Figma `001-3. 친구 초대`(node 1529:84745).
///
/// Store/Coordinator 를 모른다 — 값과 콜백만 받는다. 버튼 동작(공유·초대 링크)은 아직 미연결이라
/// 콜백은 기본값 `{}` 로 열어두기만 한다.
struct InviteFriendsContent: View {
    var onTapBack: () -> Void = {}
    var onTapSkip: () -> Void = {}
    var onTapInvite: () -> Void = {}
    var onTapCopyLink: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            MHTopNavigation(onBack: onTapBack, onSkip: onTapSkip)
            titleAndDescription
            actionArea
        }
        .background(Color.mhBackgroundNormalNormal)
    }

    // MARK: - Title / Illustration / Description

    private var titleAndDescription: some View {
        VStack(spacing: 0) {
            Text("친구들을 초대해볼까요?")
                .mhTypography(.title3Bold)
                .foregroundStyle(Color.mhPrimaryNormal)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 24)

            VStack(spacing: 40) {
                illustration
                Text("\"여기 어때?\"는 이제 그만\n친구가 들어오면 저장한 장소가 한눈에 모여요.\n다음 약속 장소, 여기서 같이 골라요.")
                    .mhTypography(.label1NormalRegular)
                    .foregroundStyle(Color.mhPrimaryNormal)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity)
    }

    // NOTE(에셋): Figma 원본도 실제 일러스트 없이 단색(#D9D9D9) placeholder 다 — 디자인팀 에셋 미출고 상태.
    // 하드코딩 hex 대신 가장 가까운 중립 채움 토큰(Fill/Normal)으로 대체. 실제 일러스트 에셋 다운로드 필요.
    private var illustration: some View {
        Rectangle()
            .fill(Color.mhFillNormal)
            .frame(width: 220, height: 220)
    }

    // MARK: - Action Area

    // NOTE: MHActionArea(.strong) 이 구조는 동일(main solid + alternative outlined, 세로 스택)하지만
    // MHAction 이 leadingIcon 을 못 받아 대체 버튼의 링크 아이콘을 표현 못 함 → MHButton 을 직접 조립.
    private var actionArea: some View {
        VStack(spacing: 8) {
            MHButton("친구 초대하기", variant: .solid, color: .primary, size: .large, action: onTapInvite)
                .mhButtonFillWidth()
            MHButton("초대 링크 복사", variant: .outlined, color: .primary, size: .large, leadingIcon: .link, action: onTapCopyLink)
                .mhButtonFillWidth()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
}

#Preview {
    InviteFriendsContent()
}
