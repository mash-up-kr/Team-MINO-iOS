import DesignSystem
import SwiftUI

/// 튜토리얼 4단계 — 완료 피드백. Figma `000-4. 완료 피드백`(node 1529:84668).
///
/// 버튼 없이 잠깐 보여주고 넘어가는 화면이라 조작 요소가 없다.
struct TutorialCompleteContent: View {
    var body: some View {
        VStack(spacing: 60) {
            Image("tutorialComplete", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: 320, height: 260)

            textBlock
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.mhBackgroundNormalNormal)
        // 홈 인디케이터 영역까지가 세로 중앙 정렬의 기준이다(Figma: 상태바 아래 54 ~ 화면 끝 812).
        .ignoresSafeArea(edges: .bottom)
    }

    private var textBlock: some View {
        VStack(spacing: 4) {
            Text("튜토리얼 완료")
                .mhTypography(.display3Bold)
            Text("이제 진짜 SNS 핫플을 공유해보세요")
                .mhTypography(.body1ReadingRegular)
        }
        .foregroundStyle(Color.mhPrimaryNormal)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) { backgroundCircle }
    }

    /// 문구 뒤에서 아래를 채우는 옅은 원(Figma `Ellipse 294` 655pt, 상단이 문구보다 27pt 위).
    /// 화면 밖으로 나가는 큰 도형이라 레이아웃에 영향을 주지 않게 background 로 얹는다.
    private var backgroundCircle: some View {
        Circle()
            .fill(Color.mhBackgroundNormalAlternative)
            .frame(width: 655, height: 655)
            .offset(y: -27)
    }
}

#Preview {
    TutorialCompleteContent()
}
