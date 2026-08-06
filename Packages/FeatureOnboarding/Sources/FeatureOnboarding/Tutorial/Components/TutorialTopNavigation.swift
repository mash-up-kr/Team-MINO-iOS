import DesignSystem
import SwiftUI

/// 튜토리얼 상단 내비게이션. Figma `Top Navigation/Top Navigation`(node 2314:58856).
///
/// 가운데 타이틀 + 우측 `건너뛰기` 텍스트 버튼 구성이다.
/// 타이틀은 폭이 길어져도 우측 버튼을 밀지 않도록 오버레이로 얹는다.
struct TutorialTopNavigation: View {
    var title: String
    var onTapSkip: () -> Void = {}

    var body: some View {
        Text(title)
            .mhTypography(.headline2Bold)
            .foregroundStyle(Color.mhLabelStrong)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .overlay(alignment: .trailing) {
                Button(action: onTapSkip) {
                    // NOTE: MHTextButton 은 Body1Bold(16) 고정이라 Figma 스펙(Label1Medium 14)과 달라 직접 조립.
                    Text("건너뛰기")
                        .mhTypography(.label1NormalMedium)
                        .foregroundStyle(Color.mhLabelNormal)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }
}

#Preview {
    TutorialTopNavigation(title: "튜토리얼")
}
