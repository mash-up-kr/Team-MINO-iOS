import SwiftUI

/// 액션 영역의 배치 방식. `strong`(세로 풀폭 스택)·`neutral`(가로 행)·`cancel`(단일 outlined).
public enum MHActionAreaVariant: Sendable { case strong, neutral, cancel }

/// Action Area 안의 버튼 하나(라벨 + 탭 동작).
///
/// `variant`·`color` 로 그 슬롯의 기본 버튼 스타일을 덮어쓸 수 있다(Figma `customize = button`).
/// 안 주면 배치(variant)별 기본값을 따른다 — 예: strong 의 main 은 solid/primary.
public struct MHAction {
    public let title: String
    public let variant: MHButtonVariant?
    public let color: MHButtonColor?
    public let action: () -> Void

    public init(
        _ title: String,
        variant: MHButtonVariant? = nil,
        color: MHButtonColor? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.color = color
        self.action = action
    }
}

/// 화면 하단에 CTA 버튼을 배치하는 영역. Figma `Action Area`.
///
/// 버튼은 ``MHButton`` 을 그대로 조립하며, ``MHActionAreaVariant`` 로 배치가 갈린다:
/// - `strong`: 세로 풀폭 — 메인(solid/primary) / 대체(outlined/primary) / 보조(텍스트 링크)
/// - `neutral`: 가로 행 — 보조(outlined/assistive·hug) / 대체(outlined/primary·fill) / 메인(solid/primary·fill)
/// - `cancel`: 단일 풀폭 outlined/assistive
///
/// `divider`·`sticky`·`safeArea`·`caption` 과 `extra` 슬롯(``MHActionAreaSummary`` 등 Preset)을 조합한다.
///
/// `sticky` 와 `safeArea` 는 이름이 비슷하지만 담당이 다르다:
/// - `sticky`: **배경**. 켜면 불투명 채움(+상단 20pt 페이드)을 깔아 뒤로 지나가는 스크롤 콘텐츠를 가린다.
///   배경은 `safeArea` 값과 무관하게 화면 바닥(홈 인디케이터)까지 내려간다.
/// - `safeArea`: **높이**. 켜면 하단에 홈 인디케이터 높이만큼 여백을 넣어 버튼을 띄운다.
///   `safeAreaInset(edge: .bottom)` 으로 이 컴포넌트를 붙이는 화면은 SwiftUI 가 이미 띄워 주므로 꺼야 한다.
/// 각 액션의 버튼 스타일은 ``MHAction`` 의 `variant`·`color` 로 슬롯 기본값을 덮어쓸 수 있다(`customize = button`).
///
/// > `outlined` 는 옅은 `Line/Normal/Neutral` 테두리, `outlinedStrong` 은 진한 `Primary/Normal`(검정)
/// > 테두리(Figma customize 예시의 강조 아웃라인). `color` 는 solid 의 배경/글자색에 반영된다.
///
/// ```swift
/// MHActionArea(main: .init("메인 액션") { next() })
///
/// // customize = button: main 을 solid 대신 검정 테두리 아웃라인으로 스왑
/// MHActionArea(main: .init("메인 액션", variant: .outlinedStrong) { next() },
///              alternative: .init("대체 액션") { back() })
///
/// MHActionArea(variant: .strong,
///              main: .init("메인 액션") { next() },
///              alternative: .init("대체 액션") { back() },
///              sub: .init("보조 액션") { skip() },
///              caption: "필요한 경우 설명을 덧붙입니다.")
///
/// MHActionArea(main: .init("결제") { pay() }) {                     // extra(Preset) 슬롯
///     MHActionAreaSummary(label: "결제 금액", value: "12,000원")
/// }
/// ```
public struct MHActionArea<Extra: View>: View {
    private let variant: MHActionAreaVariant
    private let main: MHAction
    private let alternative: MHAction?
    private let sub: MHAction?
    private let caption: String?
    private let divider: Bool
    private let sticky: Bool
    private let safeArea: Bool
    private let extra: Extra

    public init(
        variant: MHActionAreaVariant = .strong,
        main: MHAction,
        alternative: MHAction? = nil,
        sub: MHAction? = nil,
        caption: String? = nil,
        divider: Bool = false,
        sticky: Bool = false,
        safeArea: Bool = true,
        @ViewBuilder extra: () -> Extra = { EmptyView() }
    ) {
        self.variant = variant
        self.main = main
        self.alternative = alternative
        self.sub = sub
        self.caption = caption
        self.divider = divider
        self.sticky = sticky
        self.safeArea = safeArea
        self.extra = extra()
    }

    @State private var bottomInset: CGFloat = 0

    /// extra 슬롯에 실제 콘텐츠가 있는지(기본값 EmptyView 면 없음). 없으면 extra 블록을 통째로 생략한다.
    private var hasExtra: Bool { Extra.self != EmptyView.self }

    public var body: some View {
        VStack(spacing: 0) {
            if divider {
                Rectangle()
                    .fill(Color.mhLineNormalNeutral)
                    .frame(height: 1)
            }
            // extra(Preset)는 actions 컨테이너와 분리된 블록. 상단 20·하단 4 → actions 상단 20 과 합쳐 버튼과 24.
            if hasExtra {
                extra
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 4)   // Figma margin/action/contents-bottom
            }
            VStack(spacing: 16) {   // caption · actions (caption 은 버튼과 16)
                if let caption {
                    Text(caption)
                        .mhTypography(.label2Regular)
                        .foregroundStyle(Color.mhLabelAlternative)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                actions
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
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
                button(main, slot: "main", variant: .solid, color: .primary)
                    .mhButtonFillWidth()
                if let alternative {
                    button(alternative, slot: "alternative", variant: .outlined, color: .primary)
                        .mhButtonFillWidth()
                }
                if let sub {
                    MHActionSubLink(title: sub.title, action: sub.action)
                        .accessibilityIdentifier("MHActionArea.sub")
                }
            }
        case .neutral:
            HStack(spacing: 12) {
                if let sub {
                    button(sub, slot: "sub", variant: .outlined, color: .assistive)  // hug
                }
                if let alternative {
                    button(alternative, slot: "alternative", variant: .outlined, color: .primary)
                        .mhButtonFillWidth()
                }
                button(main, slot: "main", variant: .solid, color: .primary)
                    .mhButtonFillWidth()
            }
        case .cancel:
            button(main, slot: "main", variant: .outlined, color: .assistive)
                .mhButtonFillWidth()
        }
    }

    // 슬롯 버튼 — action 의 variant/color 오버라이드(customize=button)가 있으면 그걸, 없으면 슬롯 기본값.
    // 식별자는 슬롯 고정("MHActionArea.main" 등) — 액션 영역은 화면당 하나라 화면 안에서 유일하다.
    private func button(
        _ action: MHAction,
        slot: String,
        variant defaultVariant: MHButtonVariant,
        color defaultColor: MHButtonColor
    ) -> some View {
        MHButton(
            action.title,
            variant: action.variant ?? defaultVariant,
            color: action.color ?? defaultColor,
            size: .large,
            action: action.action
        )
        .accessibilityIdentifier("MHActionArea.\(slot)")
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
            // 배경만 홈 인디케이터 띠까지 내려 깐다. `safeArea == false` 로 그 띠에 여백을 두지 않는 화면
            // (스크롤뷰 위에 safeAreaInset 으로 얹는 경우)에서도 아래 콘텐츠가 비쳐 보이지 않게 한다.
            // 넓히는 건 `.container` 뿐이라 레이아웃과 키보드 회피는 그대로다.
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    private var safeAreaReader: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { bottomInset = proxy.safeAreaInsets.bottom }
                .onChange(of: proxy.safeAreaInsets.bottom) { _, newValue in bottomInset = newValue }
        }
        // 키보드는 빼고 컨테이너 인셋(홈 인디케이터)만 잰다. 안 빼면 키보드가 올라올 때 인셋이
        // 300pt 넘게 잡혀 `safeArea == true` 인 화면의 액션 영역이 그만큼 부풀고 본문이 찌그러진다.
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

// MARK: - Sub Action(텍스트 링크) — strong 전용

struct MHActionSubLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .mhTypography(.label1NormalBold)
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

#Preview("MHActionArea") {
    VStack(spacing: 32) {
        MHActionArea(
            variant: .strong,
            main: .init("메인 액션") {},
            alternative: .init("대체 액션") {},
            sub: .init("보조 액션") {},
            caption: "필요한 경우 설명을 덧붙입니다."
        )
        MHActionArea(
            variant: .strong,
            main: .init("메인 액션", variant: .outlinedStrong) {},
            alternative: .init("대체 액션") {}
        )
        MHActionArea(variant: .cancel, main: .init("확인") {})
    }
}
