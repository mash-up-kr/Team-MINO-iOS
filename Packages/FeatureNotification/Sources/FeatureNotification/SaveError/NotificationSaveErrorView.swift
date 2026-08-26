import DesignSystem
import SwiftUI

/// 저장 오류 알림 카드를 탭하면 push 되는 안내 화면. Figma `007-2 저장 오류 시`(node 3037:91057).
///
/// Store 를 모르는 순수 뷰 — 정적 안내 문구뿐이라 표시 모델 없이 `onTapBack` 클로저만 받는다.
///
/// 일러스트 + 제목 + 본문 골격은 ``MHIllustratedMessage`` 가 그린다. 좌우 인셋(38)·제목 아래
/// 간격(24)·본문 줄 간격(12)이 그 부품의 값과 같아, 여기서 다시 만들면 같은 수치가 두 곳으로
/// 갈라진다.
///
/// 하단 탭바는 이 화면이 그리지 않는다. Figma 상 탭바가 보이는 건 이 화면이 탭 콘텐츠 영역 위로
/// push 되며 `MainTabView` 의 `safeAreaInset` 탭바가 그 아래 유지되기 때문이다.
struct NotificationSaveErrorContentView: View {
    let onTapBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MHTopNavigation(onBack: onTapBack)

            // TODO: 디자이너 에셋 전달 대기(다크모드 변형 포함). 도착 전까지는 일러스트가
            // 통째로 접히고 문구만 보인다 — 빈 칸을 남기지 않는다.
            MHIllustratedMessage(
                illustration: .mhAssetIfAvailable("notificationSaveErrorIllustration", bundle: .module),
                title: "확인해주세요",
                messages: [
                    "현재 한국 내 장소만 지원됩니다.",
                    "사진 속 장소인식은 아직 지원하지 않습니다",
                    "본문에 주소나 장소명을 포함해주세요",
                ],
                alignment: .leading,
                // Figma: 일러스트 bottom(86 + 299 = 385) → 타이틀 top(542 − 54 = 488) 간격 = 103.
                illustrationSpacing: 103
            )
            // Figma: Top Navigation 콘텐츠 높이(98 − 상태바 54 = 44) 기준, 일러스트 top(140 − 54 = 86)
            // 까지 간격 = 86 − 44 = 42.
            .padding(.top, 42)
            // 제목에 직접 붙이던 identifier 를 컨테이너 단위로 올린다 — 골격이 부품 안으로
            // 들어가 호출부가 개별 요소에 붙일 수 없다.
            .accessibilityIdentifier("NotificationSaveError.message")

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.mhBackgroundNormalNormal)
    }
}

// MARK: - Preview

#Preview("NotificationSaveError") {
    NotificationSaveErrorContentView(onTapBack: {})
}

#Preview("NotificationSaveError — Dark") {
    NotificationSaveErrorContentView(onTapBack: {})
        .preferredColorScheme(.dark)
}
