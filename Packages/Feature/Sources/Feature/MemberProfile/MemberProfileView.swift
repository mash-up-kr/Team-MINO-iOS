import SwiftUI
import Domain

/// 회원 프로필 화면.
/// ViewModel 의 상태(로딩/성공/실패)를 그리며, UseCase 는 ViewModel 을 통해서만 접근한다.
/// 자동화·VoiceOver 를 위해 인터랙션·상태 요소에 accessibilityIdentifier 를 부여한다.
/// DesignSystem(DSKit) 이 SwiftUI 토큰을 확정하기 전까지는 SwiftUI 기본 스타일을 쓴다.
public struct MemberProfileView: View {
    private let viewModel: MemberProfileViewModel

    public init(viewModel: MemberProfileViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background)
            .task { await viewModel.load() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("불러오는 중…")
                .accessibilityIdentifier("MemberProfile.loading")

        case .loaded(let member):
            VStack(spacing: 8) {
                Text(member.name)
                    .font(.title.bold())
                    .accessibilityIdentifier("MemberProfile.nameLabel")
                if let email = member.email {
                    Text(email)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("MemberProfile.emailLabel")
                }
            }
            .padding(24)

        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .font(.body)
                    .accessibilityIdentifier("MemberProfile.errorLabel")
                Button("다시 시도") {
                    Task { await viewModel.load() }
                }
                .accessibilityIdentifier("MemberProfile.retryButton")
            }
            .padding(24)
        }
    }
}
