import DesignSystem
import SwiftUI

/// 튜토리얼 4단계 — 완료 피드백. Figma `000-2 튜토리얼 완료`(node 2314:58952).
///
/// 버튼 없이 잠깐 보여주고 넘어가는 화면이라 조작 요소가 없다.
struct TutorialCompleteContent: View {
    var body: some View {
        // 간격 116 — Figma 일러스트 바닥(478)과 문구 상단(594) 사이(node 2314:58965 / 2314:58966).
        VStack(spacing: 116) {
            Image("tutorialComplete", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: 320, height: 260)

            textBlock
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(alignment: .bottom) { cloudBackground }
        .background(Color.mhBackgroundNormalNormal)
        // 홈 인디케이터 영역까지가 세로 중앙 정렬의 기준이다(Figma: 상태바 아래 54 ~ 화면 끝 812).
        .ignoresSafeArea(edges: .bottom)
    }

    private var textBlock: some View {
        VStack(spacing: 4) {
            Text("튜토리얼 완료")
                .accessibilityIdentifier("TutorialComplete.title")
                .mhTypography(.display3Bold)
            Text("이제 진짜 SNS 핫플을 공유해보세요")
                .mhTypography(.body1ReadingRegular)
        }
        .foregroundStyle(Color.mhPrimaryNormal)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    /// 화면 하단을 채우는 옅은 구름 장식(Figma `BG` 375×325 — 튜토리얼 안내 화면과 같은 에셋).
    /// 벡터 여러 개의 boolean union 이라 코드로 그리지 않고 에셋으로 받았다.
    private var cloudBackground: some View {
        Image("tutorialCloudBackground", bundle: .module)
            .resizable()
            .scaledToFill()
            .frame(height: 325)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityHidden(true)
    }
}

#Preview {
    TutorialCompleteContent()
}
