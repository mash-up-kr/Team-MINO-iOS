import DesignSystem
import SwiftUI

/// 세션을 확보하는 동안 머무는 화면. **`LaunchScreen.storyboard` 와 같은 그림을 그린다** —
/// 스토리보드에서는 Swift 가 돌지 않아 여기가 앱의 첫 코드다. 두 화면이 어긋나면
/// 앱을 켤 때마다 그림이 튀어 보인다.
///
/// 배경이 시맨틱 컬러가 아니라 고정 흰색인 것도 스토리보드와 같은 이유다 —
/// 워드마크가 검정으로 구워져 있어 다크 모드에서 뒤집히면 보이지 않는다.
struct LaunchSplashView: View {
    /// nil 이면 로딩 중이다. 값이 있으면 재시도 UI 를 얹는다.
    var onRetry: (() -> Void)?

    private static let failureMessage = "인터넷 연결을 확인한 뒤 다시 시도해 주세요"

    // 스토리보드 constraint 의 multiplier 를 그대로 옮긴 값이다. 한쪽만 고치면 전환이 튄다.
    private enum Ratio {
        static let cloudHeight: CGFloat = 0.400246
        static let charactersWidth: CGFloat = 0.861333
        static let charactersHeight: CGFloat = 0.434729
        /// 스토리보드는 superview 의 centerY(= 높이의 절반)에 곱하므로 절반을 미리 반영했다.
        static let charactersCenterY: CGFloat = 0.764778 / 2
        static let wordmarkHeight: CGFloat = 0.14942
        static let wordmarkCenterY: CGFloat = 1.62479 / 2
        /// 캐릭터 하단(≈0.60)과 워드마크 상단(≈0.74) 사이.
        static let retryCenterY: CGFloat = 0.67
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Color.white

                Image("splashCloud")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height * Ratio.cloudHeight)
                    .clipped()
                    .frame(maxHeight: .infinity, alignment: .bottom)

                Image("splashCharacters")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(
                        width: size.width * Ratio.charactersWidth,
                        height: size.height * Ratio.charactersHeight
                    )
                    .centered(in: size, atY: Ratio.charactersCenterY)

                Image("splashWordmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height * Ratio.wordmarkHeight)
                    .centered(in: size, atY: Ratio.wordmarkCenterY)

                if let onRetry {
                    // 캐릭터 아래·워드마크 위의 빈 띠에 앉힌다. 화면 바닥에 두면
                    // 워드마크에 구워진 캡션과 겹친다(둘 사이 여백이 그만큼 없다).
                    retry(onRetry)
                        .frame(width: size.width)
                        .centered(in: size, atY: Ratio.retryCenterY)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("Launch.splash")
    }

    private func retry(_ onRetry: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            Text(Self.failureMessage)
                .mhTypography(.body1NormalMedium)
                .foregroundStyle(Color.mhLabelNeutral)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("Launch.errorMessage")

            MHButton("다시 시도", action: onRetry)
                .accessibilityIdentifier("Launch.retryButton")
        }
        .padding(.horizontal, 24)
    }
}

private extension View {
    /// 가로 중앙, 세로는 높이 비율. 스토리보드 constraint 를 그대로 옮기기 위한 형태다.
    func centered(in size: CGSize, atY ratio: CGFloat) -> some View {
        position(x: size.width / 2, y: size.height * ratio)
    }
}

#Preview("로딩") {
    LaunchSplashView()
}

#Preview("재시도") {
    LaunchSplashView(onRetry: {})
}
