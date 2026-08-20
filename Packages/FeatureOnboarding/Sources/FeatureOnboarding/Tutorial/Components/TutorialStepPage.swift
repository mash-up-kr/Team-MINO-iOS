import DesignSystem
import SwiftUI

/// 튜토리얼 한 스텝. 번호 뱃지 + 두 줄 제목 + 예시 카드. Figma `000-1 튜토리얼_step 1`(node 3798:167079) 외 4장.
///
/// 스텝마다 달라지는 건 이 세 가지뿐이라, 다섯 장을 한 뷰로 그린다.
struct TutorialStepPage: View {
    /// Figma 카드 305×420. 화면이 좁으면 이 비율을 지킨 채 줄어든다.
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

    // MARK: - 번호 + 제목

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(step.id)")
                .mhTypography(.body2NormalBold)
                // Figma 는 Static/White 지만 그건 라이트 기준 값이다 — 다크에서 Primary/Normal 이 흰색으로
                // 뒤집혀 흰 원에 흰 글자가 된다. Primary/Normal 위 글자는 MHButton(solid/primary)과 같은 토큰을 쓴다.
                .foregroundStyle(Color.mhInverseLabel)
                .frame(width: 28, height: 28)
                .background(Color.mhPrimaryNormal, in: Circle())
                // 번호는 진행 표시일 뿐이라 따로 읽지 않는다 — 아래 dot 인디케이터가 같은 말을 한다.
                .accessibilityHidden(true)

            Text(step.title)
                .mhTypography(.heading1Bold)
                .foregroundStyle(Color.mhPrimaryNormal)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("Tutorial.stepTitle")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 예시 카드

    private var card: some View {
        illustration
            .aspectRatio(Self.cardSize.width / Self.cardSize.height, contentMode: .fit)
            .frame(maxWidth: Self.cardSize.width, maxHeight: Self.cardSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            // 남는 세로 공간을 카드가 받아 위에 붙는다 — 화면이 커져도 카드가 늘어나진 않는다.
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
            // 시안이 아직 없는 자리. Figma 의 회색 카드를 그대로 옮겨, 빠진 게 눈에 띄게 둔다.
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
