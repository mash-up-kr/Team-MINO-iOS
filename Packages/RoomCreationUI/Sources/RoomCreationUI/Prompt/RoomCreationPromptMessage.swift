import DesignSystem
import SwiftUI

/// 공동방이 하나도 없을 때 보여주는 일러스트 + 문구. Figma `001-2-1` 과 저장 탭 빈 상태가 **같은 블록**이다.
///
/// 두 곳이 사용자에게는 이어진 흐름(빈 상태 → 유도 시트)으로 보이는데, 복제해 두면 카피 한 글자를
/// 고쳤을 때 한쪽만 반영돼도 빌드·테스트가 모두 통과한다.
///
/// CTA 는 자리마다 달라(빈 상태는 ``MHButton``, 시트는 ``MHActionArea``) 포함하지 않는다.
/// 바깥에서 같은 간격(24)의 `VStack` 에 이어 붙이면 시안과 같은 배치가 된다.
public struct RoomCreationPromptMessage: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 24) {
            // Figma `2314:95486` 실측 — 정사각 160 슬롯. 에셋도 정사각이라 잘리지 않는다.
            Image(MHIllustration.emptyRoom)
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("공동방을 생성해보세요!")
                    .mhTypography(.title3Bold)
                    .foregroundStyle(.mhPrimaryNormal)

                Text("\"저번에 말한 거기가 어디였지?\"\n더 이상 묻지 마세요.")
                    .mhTypography(.label1NormalRegular)
                    .foregroundStyle(.mhLabelAlternative)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    RoomCreationPromptMessage()
        .padding(20)
}
