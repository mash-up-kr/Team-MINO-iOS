import DesignSystem
import SwiftUI

/// 홈 사용 가이드 오버레이 (Figma 「홈 사용 가이드」, node 3406-201827).
/// 최초 진입 1회만 뜨고 우상단 X 로 닫는다.
///
/// **탭바 위까지 덮어야 해서 홈 안이 아니라 앱 루트(MainTabView)가 그린다.**
/// 탭바는 MainTabView 가 safeAreaInset 으로 붙이므로, 홈 콘텐츠 안에 두면 딤이 탭바 아래에 깔린다.
/// 상태·정책은 홈이 들고(HomeState.isGuidePresented) 화면만 여기서 조립한다.
public struct HomeGuideOverlay: View {
    private let onClose: () -> Void

    public init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    public var body: some View {
        ZStack(alignment: .top) {
            // 딤은 화면 전체(상태바·탭바 포함). 탭은 여기서 막혀 뒤 카드 덱이 스와이프되지 않는다.
            // Figma `Rectangle 6291` = rgba(0,0,0,0.8) — 방 리스트 딤(0.7)과 값이 다르니 같이 맞추지 않는다.
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .accessibilityIdentifier("Home.guide.dim")

            closeButton
            guideBlock
        }
        .accessibilityIdentifier("Home.guide")
    }

    /// 우상단 닫기 — Figma: 28×28, 우측 인셋 20, 상단(세이프에어리어 기준) 30.
    private var closeButton: some View {
        Button(action: onClose) {
            Image(.close)
                .resizable()
                .renderingMode(.template)
                .frame(width: 28, height: 28)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 20)
        .padding(.top, 30)
        .accessibilityLabel("가이드 닫기")
        .accessibilityIdentifier("Home.guide.closeButton")
    }

    /// 손 그래픽 + 안내 문구.
    ///
    /// 둘을 VStack 으로 묶지 않고 각각 상단 오프셋으로 놓는다 — 손 에셋은 그림자 여백을 포함해
    /// 실제 그림(40×63)보다 훨씬 큰 96×119 라, 스택으로 쌓으면 그 여백만큼 문구가 밀려난다.
    /// 카드 덱이 상단 기준 배치라 오프셋도 세이프에어리어 상단 기준이어야 기기가 커져도 카드 위에 얹힌다.
    @ViewBuilder
    private var guideBlock: some View {
        // Figma: 그림 상단 519.1 − 그림자 여백 4.0 − 상태바 44 = 471.1
        Image(dsImage: "homeGuideHand")
            .resizable()
            .frame(width: 96.25, height: 119.48)   // 그림자 포함 원본 크기(그림 자체는 40.25×63.48)
            .frame(maxWidth: .infinity)
            .padding(.top, 471.1)
            .accessibilityHidden(true)             // 장식 — 안내는 아래 문구가 읽어준다
            .accessibilityIdentifier("Home.guide.handGraphic")

        Text("좌우로 스와이프하며 카드를 탐색해 보세요.")
            .mhTypography(.body1NormalMedium)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 556.6)                  // Figma: 문구 상단 600.6 − 상태바 44
            .accessibilityIdentifier("Home.guide.copy")
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.mhBackgroundNormalAlternative
        HomeGuideOverlay(onClose: {})
    }
}
