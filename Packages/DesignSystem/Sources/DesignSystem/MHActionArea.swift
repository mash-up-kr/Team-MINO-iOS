import SwiftUI

// MARK: - Action Area (골격)
//
// Figma `Action Area`. 화면 하단에 CTA 버튼을 배치하는 영역이다.
// 이 파일은 **골격**(variant·divider·sticky·safeArea)만 다룬다.
// (Extra/Preset 콘텐츠·caption 은 후속 청크 C에서 추가)
//
//     MHActionArea(main: .init("메인 액션") { })                                   // strong 기본
//     MHActionArea(variant: .strong,
//                  main: .init("메인 액션") { },
//                  alternative: .init("대체 액션") { },
//                  sub: .init("보조 액션") { })
//     MHActionArea(variant: .neutral, main: .init("메인") { }, alternative: .init("대체") { }, sub: .init("보조") { })
//     MHActionArea(variant: .cancel, main: .init("확인") { })
//
// 버튼은 `MHButton` 을 그대로 조립한다.
// - strong : 세로 풀폭 스택 — 메인(solid/primary) / 대체(outlined/primary) / 보조(텍스트 링크)
// - neutral: 가로 행 — 보조(outlined/assistive·hug) / 대체(outlined/primary·fill) / 메인(solid/primary·fill)
// - cancel : 단일 풀폭 outlined/assistive
//
// 컨테이너 여백 20/20, 액션 간격 strong 8·neutral 12. sticky 시 Background/Elevated/Normal + 상단 페이드.
// (Figma 의 `Compact (Web Only)` 는 "앱 미대응" 명시라 iOS 에서 제외)

public enum MHActionAreaVariant: Sendable { case strong, neutral, cancel }

/// Action Area 안의 버튼 하나(라벨 + 동작)
public struct MHAction {
    public let title: String
    public let action: () -> Void
    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
}

public struct MHActionArea: View {
    private let variant: MHActionAreaVariant
    private let main: MHAction
    private let alternative: MHAction?
    private let sub: MHAction?
    private let divider: Bool
    private let sticky: Bool
    private let safeArea: Bool

    public init(
        variant: MHActionAreaVariant = .strong,
        main: MHAction,
        alternative: MHAction? = nil,
        sub: MHAction? = nil,
        divider: Bool = false,
        sticky: Bool = false,
        safeArea: Bool = true
    ) {
        self.variant = variant
        self.main = main
        self.alternative = alternative
        self.sub = sub
        self.divider = divider
        self.sticky = sticky
        self.safeArea = safeArea
    }

    @State private var bottomInset: CGFloat = 0

    public var body: some View {
        VStack(spacing: 0) {
            if divider {
                Rectangle()
                    .fill(Color.mhLineNormalNormal)   // NOTE(확인): divider 색 토큰 미제공 → Line/Normal/Normal 추정
                    .frame(height: 1)
            }
            actions
                .padding(.horizontal, 20)   // Figma margin/action/normal-horizontal
                .padding(.vertical, 20)     // margin/action/normal-vertical
            if safeArea {
                Color.clear.frame(height: bottomInset)   // Bottom Safe Area(홈 인디케이터) — 실제 인셋
            }
        }
        .frame(maxWidth: .infinity)
        .background(alignment: .bottom) { stickyBackground }
        .background(safeAreaReader)   // 하단 안전영역 인셋 측정
    }

    // MARK: 액션 배치(variant별)

    @ViewBuilder private var actions: some View {
        switch variant {
        case .strong:
            VStack(spacing: 8) {
                MHButton(main.title, variant: .solid, color: .primary, size: .large, action: main.action)
                    .mhButtonFillWidth()
                if let alternative {
                    MHButton(alternative.title, variant: .outlined, color: .primary, size: .large, action: alternative.action)
                        .mhButtonFillWidth()
                }
                if let sub {
                    MHActionSubLink(title: sub.title, action: sub.action)
                }
            }
        case .neutral:
            HStack(spacing: 12) {
                if let sub {
                    MHButton(sub.title, variant: .outlined, color: .assistive, size: .large, action: sub.action)  // hug
                }
                if let alternative {
                    MHButton(alternative.title, variant: .outlined, color: .primary, size: .large, action: alternative.action)
                        .mhButtonFillWidth()
                }
                MHButton(main.title, variant: .solid, color: .primary, size: .large, action: main.action)
                    .mhButtonFillWidth()
            }
        case .cancel:
            MHButton(main.title, variant: .outlined, color: .assistive, size: .large, action: main.action)
                .mhButtonFillWidth()
        }
    }

    // MARK: sticky 배경(Elevated + 상단 페이드)

    @ViewBuilder private var stickyBackground: some View {
        if sticky {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.mhBackgroundElevatedNormal.opacity(0), .mhBackgroundElevatedNormal],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 20)   // Figma: 상단 20px 페이드
                Rectangle().fill(Color.mhBackgroundElevatedNormal)
            }
            .allowsHitTesting(false)
        }
    }

    private var safeAreaReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { bottomInset = proxy.safeAreaInsets.bottom }
                .onChange(of: proxy.safeAreaInsets.bottom) { _, newValue in bottomInset = newValue }
        }
    }
}

// MARK: - Sub Action(텍스트 링크) — strong 전용

struct MHActionSubLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .mhTypography(.label1NormalBold)          // SUITE Bold 14
                .foregroundStyle(Color.mhLabelAlternative)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
        }
        .buttonStyle(MHSubLinkStyle())
        .padding(.vertical, 8)
    }
}

private struct MHSubLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: 6).fill(Color.mhLabelNormal.opacity(0.08))
                }
            }
    }
}
