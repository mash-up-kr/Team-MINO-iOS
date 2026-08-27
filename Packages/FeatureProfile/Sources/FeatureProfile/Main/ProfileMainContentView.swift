import DesignSystem
import ProfileSetupUI
import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md — Store 를 모르는 순수 마크업(state + send 만 받는다).
//
// Figma `008-1 마이페이지`(node 2542:124589). 좌표는 합성 프레임에서 실측했고, 논리 위치는
// 상태바(54, Status Bar 인스턴스)를 뺀 값이다 — 이 화면은 시스템 safe area 로 그 영역을 이미 확보한다
// (``NotificationListHeader`` 와 같은 계산).
struct ProfileMainContentView: View {
    let state: ProfileMainState
    let send: (ProfileMainAction) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileSummary
                // 섹션을 가르는 12pt 띠. 화면 폭을 꽉 채우므로 좌우 여백 바깥에 둔다.
                Color.mhBackgroundNormalAlternative
                    .frame(height: Metric.bandHeight)
                settings
            }
        }
        .background(Color.mhBackgroundNormalNormal)
        .mhDialog(item: state.dialog) { dialog in
            MHDialog(
                title: dialog.title,
                message: dialog.message,
                cancel: MHAction("취소") { send(.dismissDialog) },
                confirm: MHAction("설정으로 이동") { send(.confirmDialog) }
            )
        }
    }

    // MARK: - 프로필 요약

    // 아바타(120)는 100 슬롯 위로 10 씩 넘쳐 그려진다(Figma Container/Content) — 위 여백에서 그만큼 뺀다.
    private var profileSummary: some View {
        VStack(spacing: Metric.avatarToNameGap) {
            avatar
            nameRow
        }
        .padding(.top, Metric.summaryTop - Metric.avatarBleed)
        .padding(.bottom, Metric.sectionGap)
    }

    private var avatar: some View {
        Circle()
            .fill(profileAvatarColor(for: state.avatarIndex) ?? Color.mhBackgroundNormalAlternative)
            .frame(width: Metric.avatarSize, height: Metric.avatarSize)
            .accessibilityIdentifier("ProfileMain.avatar")
    }

    // 연필까지가 하나의 편집 버튼이다 — 이름만 눌러도 같은 화면으로 간다(FR-002).
    private var nameRow: some View {
        Button { send(.tapEditProfile) } label: {
            HStack(spacing: Metric.nameToPencilGap) {
                Text(state.nickname)
                    .mhTypography(.heading2Bold)
                    .foregroundStyle(Color.mhLabelNormal)
                    .lineLimit(1)
                Image(MHIcon.pencilFill)
                    .resizable()
                    .frame(width: Metric.pencilSize, height: Metric.pencilSize)
                    .foregroundStyle(Color.mhLabelNormal)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("프로필 변경")
        .accessibilityIdentifier("ProfileMain.editProfile")
    }

    // MARK: - 앱 설정 · 서비스 정보

    private var settings: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("앱 설정")

            VStack(spacing: Metric.rowGap) {
                switchRow(
                    "알림 설정",
                    isOn: state.isNotificationOn,
                    isBusy: state.isNotificationBusy,
                    identifier: "ProfileMain.notificationSwitch"
                ) { send(.setNotification($0)) }

                switchRow(
                    "위치 설정",
                    isOn: state.isLocationOn,
                    isBusy: state.isLocationBusy,
                    identifier: "ProfileMain.locationSwitch"
                ) { send(.setLocation($0)) }
            }
            .padding(.top, Metric.titleToRowGap)

            Color.mhLineNormalAlternative
                .frame(height: Metric.dividerHeight)
                .padding(.top, Metric.sectionGap)

            sectionTitle("서비스 정보")
                .padding(.top, Metric.sectionGap)

            VStack(spacing: Metric.rowGap) {
                linkRow("약관 및 동의", identifier: "ProfileMain.terms") { send(.tapTerms) }
                linkRow("앱 리뷰 남기기", identifier: "ProfileMain.appReview") { send(.tapAppReview) }
            }
            .padding(.top, Metric.titleToRowGap)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metric.hPadding)
        .padding(.top, Metric.sectionGap)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .mhTypography(.headline1Bold)
            .foregroundStyle(Color.mhLabelNormal)
            .frame(height: Metric.titleHeight, alignment: .leading)
    }

    private func switchRow(
        _ title: String,
        isOn: Bool,
        isBusy: Bool,
        identifier: String,
        onChange: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 0) {
            rowLabel(title)
            Spacer(minLength: 0)
            // 바인딩의 set 만 흘려보내고 state 는 결과가 확정된 뒤에 바뀐다 — 낙관적 업데이트 금지(UX-003).
            // 요청 중에는 잠근다 — 시스템 팝업이 떠 있는 사이 한 번 더 눌러 반대 방향 요청이 들어가는 걸 막는다.
            Toggle("", isOn: Binding(get: { isOn }, set: onChange))
                .labelsHidden()
                .tint(Color.mhPrimaryNormal)
                .disabled(isBusy)
                .accessibilityLabel(title)
                .accessibilityIdentifier(identifier)
        }
        .frame(height: Metric.switchRowHeight)
    }

    private func linkRow(_ title: String, identifier: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowLabel(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: Metric.linkRowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func rowLabel(_ title: String) -> some View {
        Text(title)
            .mhTypography(.body1ReadingRegular)
            .foregroundStyle(Color.mhLabelNeutral)
    }

    // Figma 실측(2542:124589). 논리 y = Figma y − 54(상태바).
    private enum Metric {
        static let hPadding: CGFloat = 20
        static let summaryTop: CGFloat = 32        // safe area → 프로필 블록
        static let avatarSize: CGFloat = 120
        static let avatarBleed: CGFloat = 10       // 100 슬롯 위로 넘치는 양
        static let avatarToNameGap: CGFloat = 2
        static let nameToPencilGap: CGFloat = 2
        static let pencilSize: CGFloat = 20
        static let bandHeight: CGFloat = 12
        static let sectionGap: CGFloat = 32
        static let titleHeight: CGFloat = 26
        static let titleToRowGap: CGFloat = 16
        static let rowGap: CGFloat = 12
        static let switchRowHeight: CGFloat = 32
        static let linkRowHeight: CGFloat = 26
        static let dividerHeight: CGFloat = 2
    }
}

private extension ProfileMainDialog {
    var title: String {
        switch self {
        case .notificationBlocked: "알림 권한이 꺼져 있어요"
        case .locationBlocked: "위치 권한이 꺼져 있어요"
        case .locationTurnOff: "위치 설정은 앱에서 끌 수 없어요"
        }
    }

    var message: String {
        switch self {
        case .notificationBlocked, .locationBlocked:
            "설정 앱에서 권한을 켜면 이어서 사용할 수 있어요."
        case .locationTurnOff:
            "설정 앱에서 위치 권한을 변경할 수 있어요."
        }
    }
}

#Preview("기본") {
    ProfileMainContentView(state: .preview(nickname: "홍길동", avatarIndex: 7), send: { _ in })
}

// 프로필 조회에 실패하면 프로필 영역만 비고 앱 설정·서비스 정보는 그대로 남는다.
#Preview("프로필 조회 실패") {
    ProfileMainContentView(state: ProfileMainState(), send: { _ in })
}

#Preview("알림 ON") {
    ProfileMainContentView(
        state: .preview(nickname: "홍길동", avatarIndex: 7, isNotificationOn: true),
        send: { _ in }
    )
}

// 요청 중에는 그 행이 잠긴다 — 시스템 팝업이 떠 있는 동안의 모습.
#Preview("권한 요청 중") {
    ProfileMainContentView(
        state: .preview(nickname: "홍길동", avatarIndex: 7, isNotificationBusy: true),
        send: { _ in }
    )
}

#Preview("위치 끄기 안내") {
    ProfileMainContentView(
        state: .preview(nickname: "홍길동", avatarIndex: 7, isLocationOn: true, dialog: .locationTurnOff),
        send: { _ in }
    )
}

private extension ProfileMainState {
    static func preview(
        nickname: String,
        avatarIndex: Int?,
        isNotificationOn: Bool = false,
        isLocationOn: Bool = false,
        isNotificationBusy: Bool = false,
        dialog: ProfileMainDialog? = nil
    ) -> Self {
        var state = ProfileMainState()
        state.nickname = nickname
        state.avatarIndex = avatarIndex
        state.isNotificationOn = isNotificationOn
        state.isLocationOn = isLocationOn
        state.isNotificationBusy = isNotificationBusy
        state.dialog = dialog
        return state
    }
}
