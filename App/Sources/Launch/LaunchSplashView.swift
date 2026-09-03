import DesignSystem
import Feature
import SwiftUI

/// 세션을 확보하는 동안 머무는 화면. **`LaunchScreen.storyboard` 와 같은 그림을 그린다** —
/// 스토리보드에서는 Swift 가 돌지 않아 여기가 앱의 첫 코드다. 두 화면이 어긋나면
/// 앱을 켤 때마다 그림이 튀어 보인다.
///
/// 그 위에 얹히는 것이 시안 012-2/3/4 다 — 응답이 늦으면 스피너, 실패하면 스낵바.
/// 스토리보드에는 없는 요소라 여기서만 그린다(런치스크린에는 상태가 없다).
///
/// 배경이 시맨틱 컬러가 아니라 고정 흰색인 것도 스토리보드와 같은 이유다 —
/// 워드마크가 검정으로 구워져 있어 다크 모드에서 뒤집히면 보이지 않는다.
struct LaunchSplashView: View {
    /// 세션이 늦어지는 중(시안 012-2).
    var isSlow: Bool = false
    /// 하단 스낵바(시안 012-3 / 012-4). nil 이면 띄우지 않는다.
    var notice: AppLaunchState.Notice?

    // 스토리보드 constraint 의 multiplier 를 그대로 옮긴 값이다. 한쪽만 고치면 전환이 튄다.
    private enum Ratio {
        static let wordmarkHeight: CGFloat = 0.149421
        /// 스토리보드는 superview 의 centerY(= 높이의 절반)에 곱하므로 절반을 미리 반영했다.
        static let wordmarkCenterY: CGFloat = 0.582919 / 2
        /// 캐릭터 에셋 자체 비율(375:360). 높이가 아니라 폭에서 끌어내야 좌우 흰 여백이 없다.
        static let charactersAspect: CGFloat = 0.96
        static let charactersCenterY: CGFloat = 1.5567 / 2
    }

    // 시안 375×812 실측.
    private enum Metric {
        static let spinnerSize: CGFloat = 28
        static let snackbarBottom: CGFloat = 40   // 스크린 하단에서 40
        static let snackbarInset: CGFloat = 20
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                Color.white

                Image("splashWordmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height * Ratio.wordmarkHeight)
                    .centered(in: size, atY: Ratio.wordmarkCenterY)

                Image("splashCharacters")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.width * Ratio.charactersAspect)
                    .centered(in: size, atY: Ratio.charactersCenterY)

                if isSlow {
                    // 시안은 화면 정중앙 — 캡션 아래·캐릭터 위의 빈 띠에 걸린다.
                    MHSpinner(size: Metric.spinnerSize)
                        .centered(in: size, atY: 0.5)
                        .accessibilityIdentifier("Launch.spinner")
                }

                if let notice {
                    snackbar(notice)
                        .padding(.horizontal, Metric.snackbarInset)
                        .padding(.bottom, Metric.snackbarBottom)
                        .frame(width: size.width, height: size.height, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .clipped()
            .animation(.easeInOut(duration: 0.2), value: notice)
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("Launch.splash")
    }

    private func snackbar(_ notice: AppLaunchState.Notice) -> some View {
        MHSnackbar(title: message(for: notice), icon: .circleExclamation)
            .accessibilityIdentifier("Launch.notice")
    }

    private func message(for notice: AppLaunchState.Notice) -> String {
        switch notice {
        case .networkError:   "네트워크 연결을 확인해주세요"
        case .temporaryError: "일시적인 오류가 발생했어요"
        }
    }
}

private extension View {
    /// 가로 중앙, 세로는 높이 비율. 스토리보드 constraint 를 그대로 옮기기 위한 형태다.
    func centered(in size: CGSize, atY ratio: CGFloat) -> some View {
        position(x: size.width / 2, y: size.height * ratio)
    }
}

#Preview("012-1 기본") {
    LaunchSplashView()
}

#Preview("012-2 로딩 중") {
    LaunchSplashView(isSlow: true)
}

#Preview("012-3 네트워크 에러") {
    LaunchSplashView(notice: .networkError)
}

#Preview("012-4 일시적 오류") {
    LaunchSplashView(notice: .temporaryError)
}
