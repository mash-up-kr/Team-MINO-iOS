import DesignSystem
import SwiftUI

/// 튜토리얼 1단계 — 가짜 SNS 게시물의 공유 버튼을 눌러보게 하는 화면. Figma `000-1-1 튜토리얼_step 3`(node 2314:58846).
///
/// Store/Coordinator 를 모른다 — 콜백만 받는다. 동작 연결 전이라 기본값 `{}` 로 열어두기만 한다.
struct TutorialShareGuideContent: View {
    var onTapSkip: () -> Void = {}
    var onTapShare: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            TutorialTopNavigation(title: "튜토리얼", onTapSkip: onTapSkip)

            VStack(spacing: 30) {
                titleBlock
                MockInstagramPost(onTapShare: onTapShare) {
                    // 공유 버튼 위 6pt 에 말풍선 바닥이 닿게 — 오버레이의 top 가이드를 자기 바닥으로 옮겨 위로 밀어낸다.
                    MHTooltip("공유 버튼을 눌러보세요", position: .top)
                        .fixedSize()
                        .alignmentGuide(.top) { $0[.bottom] + 6 }
                }
            }
            .padding(20)
            .frame(maxHeight: .infinity)
        }
        .background(alignment: .bottom) { cloudBackground }
        .background(Color.mhBackgroundNormalNormal)
        .ignoresSafeArea(edges: .bottom)
    }

    /// 화면 하단을 채우는 옅은 구름 장식(Figma `BG` 375×325 — 완료 화면과 같은 에셋).
    private var cloudBackground: some View {
        Image("tutorialCloudBackground", bundle: .module)
            .resizable()
            .scaledToFill()
            .frame(height: 325)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityHidden(true)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SNS 공유 방법")
                .mhTypography(.title3Bold)
            Text("아래 공유 버튼을 눌러서 연습해보세요")
                .mhTypography(.label1NormalRegular)
        }
        .foregroundStyle(Color.mhPrimaryNormal)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    TutorialShareGuideContent()
}
