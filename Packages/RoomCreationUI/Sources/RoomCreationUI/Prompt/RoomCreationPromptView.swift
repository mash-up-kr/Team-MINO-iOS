import DesignSystem
import SwiftUI

/// 공동방이 하나도 없는 사용자에게 생성을 권하는 바텀시트. Figma `001-2-1 공동방 생성 유도`(`2314:95482`).
///
/// 시안이 딤(`Material/Dimmer`)을 동반한 모달이라 `MHBottomSheet`(딤 없는 비모달 3-detent)이 아니라
/// SwiftUI 네이티브 `.sheet` + `presentationDetents` 위에 얹는다.
///
/// **상태를 들지 않는다** — 언제 띄우고 어디로 보낼지는 이 시트를 소유한 flow 가 정한다
/// (지금은 저장 탭). 그래서 Store 없이 값·클로저만 받는다.
///
/// ```swift
/// .sheet(isPresented: $isPresented) {
///     RoomCreationPromptView(onCreate: { ... }, onLater: { ... })
///         .presentationDetents([.height(RoomCreationPromptView.detentHeight)])
/// }
/// ```
public struct RoomCreationPromptView: View {
    /// `presentationDetents(.height(_:))` 에 넘길 값. 시안 시트 높이 그대로다(812 − 324).
    ///
    /// 홈 인디케이터(34)를 빼지 않는다 — `.height` 는 하단 안전영역을 **포함한** 전체 높이라,
    /// 빼면 그만큼 본문이 눌린다(일러스트가 160 → 154 로 줄고 안내 문구가 두 줄에서 한 줄로
    /// 잘렸다). 시안의 Action Area 154 도 홈 인디케이터를 포함한 값이라 계산이 맞아떨어진다.
    public static let detentHeight: CGFloat = 812 - 324

    private let onCreate: () -> Void
    private let onLater: () -> Void

    public init(onCreate: @escaping () -> Void, onLater: @escaping () -> Void) {
        self.onCreate = onCreate
        self.onLater = onLater
    }

    public var body: some View {
        VStack(spacing: 0) {
            grabber

            RoomCreationPromptMessage()
                .padding(20)

            // 남는 높이를 여기서 먹어 액션 영역을 시트 바닥에 붙인다 — 없으면 그 높이가 액션 영역
            // 아래로 몰려 버튼이 시안보다 44pt 떠 보인다(실측).
            Spacer(minLength: 0)

            // safeArea: false — 시트 콘텐츠는 이미 안전영역 안에 놓이므로 홈 인디케이터 자리는
            // SwiftUI 가 비워 준다. 여기서 true 를 주면 액션 영역이 자기 높이를 스스로 잰
            // 안전영역 인셋으로 정하는데(``MHActionArea`` 의 `bottomInset`), 그 높이가 다시
            // 인셋 측정을 바꿔 시트 레이아웃이 수렴하지 않는다 — 시트를 띄우는 순간 앱이 멎는다.
            MHActionArea(
                main: MHAction("공동방 만들기", action: onCreate),
                sub: MHAction("나중에 만들래요", action: onLater),
                safeArea: false
            )
        }
        // `maxHeight: .infinity` 도 주지 않는다 — 같은 이유로 detent 시트 안에서 무한 높이를
        // 요구하면 레이아웃이 수렴하지 않는다. 남는 높이는 위의 `Spacer` 가 먹고,
        // 홈 인디케이터 띠까지의 배경은 `presentationBackground` 가 칠한다.
        .frame(maxWidth: .infinity)
        .background(.mhBackgroundElevatedNormal)
        .presentationBackground(.mhBackgroundElevatedNormal)
        .accessibilityIdentifier("RoomCreationPrompt.sheet")
    }

    // 그래버 — h30(py12) 안에 38×4 바. Figma `2314:95484`.
    private var grabber: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.mhFillNormal)
            .frame(width: 38, height: 4)
            .frame(height: 30)
            .accessibilityHidden(true)   // 장식 — 이 시트는 드래그 대상이 아니다
    }
}

#Preview("공동방 생성 유도") {
    Color.mhBackgroundNormalAlternative
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            RoomCreationPromptView(onCreate: {}, onLater: {})
                .presentationDetents([.height(RoomCreationPromptView.detentHeight)])
                .presentationDragIndicator(.hidden)   // 그래버는 시트가 직접 그린다
        }
}
