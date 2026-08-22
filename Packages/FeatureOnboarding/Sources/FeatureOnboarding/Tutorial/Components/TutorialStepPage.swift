import DesignSystem
import SwiftUI

/// 튜토리얼 한 스텝. 번호 뱃지 + 두 줄 제목 + 예시 카드. Figma `000-1 튜토리얼_step 1`(node 3798:167079) 외 4장.
struct TutorialStepPage: View {
    private static let cardSize = CGSize(width: 305, height: 420)

    let step: TutorialStep

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            header
            card
        }
        .padding(.top, 40)
        .padding(.horizontal, 35)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(step.id)")
                .mhTypography(.body2NormalBold)
                // Figma 는 Static/White 지만 그건 라이트 기준이다 — 다크에서 배경(Primary/Normal)이
                // 흰색으로 뒤집혀 흰 원에 흰 글자가 된다.
                .foregroundStyle(Color.mhInverseLabel)
                .frame(width: 28, height: 28)
                .background(Color.mhPrimaryNormal, in: Circle())
                .accessibilityHidden(true)

            Text(step.title)
                .mhTypography(.heading1Bold)
                .foregroundStyle(Color.mhPrimaryNormal)
                .fixedSize(horizontal: false, vertical: true)
                // TabView 가 인접 페이지를 살려 둬서 같은 식별자가 화면에 여럿 존재한다 — 번호로 가른다.
                .accessibilityIdentifier("Tutorial.stepTitle.\(step.id)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var card: some View {
        illustration
            // 좁은 화면에선 시안 크기가 안 들어가므로 비율만 지킨 채 줄인다.
            .aspectRatio(Self.cardSize.width / Self.cardSize.height, contentMode: .fit)
            .frame(maxWidth: Self.cardSize.width, maxHeight: Self.cardSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var illustration: some View {
        switch step.illustration {
        case .asset(let name):
            Image(name, bundle: .module)
                .resizable()
                .accessibilityHidden(true)
        case .placeholder(let text):
            Color.mhBackgroundNormalAlternative
                .overlay {
                    Text(text)
                        .mhTypography(.body1NormalMedium)
                        .foregroundStyle(Color.mhLabelAlternative)
                        .multilineTextAlignment(.center)
                }
                .accessibilityHidden(true)
        }
    }
}

#Preview("에셋") {
    TutorialStepPage(step: TutorialStep.all[0])
}

#Preview("플레이스홀더") {
    TutorialStepPage(step: TutorialStep.all[4])
}
