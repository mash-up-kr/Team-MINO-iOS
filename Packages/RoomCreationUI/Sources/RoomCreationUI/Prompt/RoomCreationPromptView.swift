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

            // safeArea: true — detent 높이가 홈 인디케이터를 포함하므로 액션 영역이 그 자리를
            // 자기 하단 여백으로 가져가야 시안의 Action Area 154 와 높이가 맞는다.
            MHActionArea(
                main: MHAction("공동방 만들기", action: onCreate),
                sub: MHAction("나중에 만들래요", action: onLater),
                safeArea: true
            )
        }
        // 남는 높이까지 채워야 배경이 시트 끝까지 칠해진다 — 콘텐츠만큼만 차지하면 아래쪽에
        // 시트의 반투명 바탕이 드러나 뒤의 탭바가 비친다.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.mhBackgroundElevatedNormal)
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
