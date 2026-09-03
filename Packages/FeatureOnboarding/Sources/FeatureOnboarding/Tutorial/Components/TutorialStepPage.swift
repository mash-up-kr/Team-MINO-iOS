import DesignSystem
import SwiftUI

/// 튜토리얼 한 스텝. 번호 뱃지 + 두 줄 제목 + 예시 카드 + 카드에 걸터앉은 캐릭터.
/// Figma `000-1 튜토리얼_step 1`(node 3798:167079) 외 4장.
struct TutorialStepPage: View {
    private static let cardSize = CGSize(width: 305, height: 420)
    /// 다섯 장이 같은 상자를 쓴다 — 소품이 삐져나온 만큼 여백으로 들어 있어 몸통 위치가 장마다 같다.
    private static let mascotSize = CGSize(width: 73, height: 90)
    /// 카드 오른쪽 위 모서리 기준. 카드 위로 62.4 올려 발만 카드 상단에 걸치게 한다.
    private static let mascotOffset = CGSize(width: -17.5, height: -62.4)

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
            // clipShape 뒤에 얹는다 — 앞에 두면 카드 밖으로 나온 몸통이 잘린다.
            .overlay(alignment: .topTrailing) { mascot }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var illustration: some View {
        Image(step.illustration, bundle: .module)
            .resizable()
            .accessibilityHidden(true)
    }

    private var mascot: some View {
        Image(step.mascot, bundle: .module)
            .resizable()
            .scaledToFit()
            .frame(width: Self.mascotSize.width, height: Self.mascotSize.height)
            .offset(x: Self.mascotOffset.width, y: Self.mascotOffset.height)
            .accessibilityHidden(true)
    }
}

#Preview {
    TutorialStepPage(step: TutorialStep.all[0])
}
