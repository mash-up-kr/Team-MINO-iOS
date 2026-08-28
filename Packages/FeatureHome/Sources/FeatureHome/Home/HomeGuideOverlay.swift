import DesignSystem
import SwiftUI

/// 홈 사용 가이드 오버레이 (Figma 「홈 튜토리얼」, node 4334-216197).
/// 최초 진입 1회만 뜨고 하단 "시작하기" 로 닫는다.
///
/// **탭바 위까지 덮어야 해서 홈 안이 아니라 앱 루트(MainTabView)가 그린다.**
/// 탭바는 MainTabView 가 safeAreaInset 으로 붙이므로, 홈 콘텐츠 안에 두면 CTA 가 탭바 아래에 깔린다.
/// 상태·정책은 홈이 들고(HomeState.isGuidePresented) 화면만 여기서 조립한다.
///
/// **딤은 여기가 아니라 홈 콘텐츠(``HomeContentView``)가 요소별로 건다.** 시안은 방 뱃지·마스코트·
/// 맨 앞 카드를 딤 **위**에 선명하게 남기는 스포트라이트 구조라, 화면을 통째로 덮는 한 장짜리 딤으로는
/// 그 셋을 다시 꺼낼 수 없다 — 그래서 흐려질 요소(제목·필터·뒷장 카드)와 배경만 홈이 직접 흐리고
/// (``View/homeGuideDimmed(_:)``), 여기서는 그 위에 얹히는 안내(화살표·문구·CTA)만 그린다.
///
/// 좌표는 시안(375×820, 상태바 44)에서 상태바를 뺀 값 — 세이프에어리어 상단 기준이라 기기가 커져도
/// 같은 자리에 붙는다. 가로는 마스코트가 화면 우측에 붙어 있어 **trailing 기준**으로 잡는다
/// (뱃지는 폭이 넓어 화살표 꼬리가 375 보다 넓은 화면에서도 뱃지 위에 남는다).
public struct HomeGuideOverlay: View {
    private let onStart: () -> Void

    public init(onStart: @escaping () -> Void) {
        self.onStart = onStart
    }

    public var body: some View {
        ZStack(alignment: .top) {
            touchBlocker
            roomChangeGuide
            swipeGuide
            actionArea
        }
        .accessibilityIdentifier("Home.guide")
    }

    /// 가이드가 떠 있는 동안 뒤 화면 조작을 막는 투명 판.
    /// 딤이 여기 없으므로(홈이 요소별로 건다) 터치 차단만 따로 맡는다 — 이게 없으면 흐려진 화면
    /// 뒤에서 카드 덱이 스와이프되고 뱃지·마스코트 탭으로 방 시트가 열린다.
    private var touchBlocker: some View {
        Color.clear
            .contentShape(Rectangle())   // clear 는 기본적으로 히트테스트되지 않는다
            .ignoresSafeArea()
            .accessibilityIdentifier("Home.guide.touchBlocker")
    }

    // MARK: - 방 변경 안내 (뱃지 · 마스코트)

    /// 방 뱃지에서 올라오는 긴 화살표 + 마스코트에서 내려오는 짧은 화살표 + 문구.
    /// 셋을 VStack 으로 묶지 않고 각각 상단 오프셋으로 놓는다 — 가리키는 대상(뱃지·마스코트)이
    /// 서로 다른 자리에 고정돼 있어 스택으로 쌓으면 화살표 끝이 대상에서 떨어진다.
    @ViewBuilder
    private var roomChangeGuide: some View {
        // Figma Vector 298: 뱃지 아래에서 시작해 문구 첫 줄을 가리킨다(에셋에 화살촉 포함).
        Image(dsImage: "homeGuideBadgeArrow")
            .resizable()
            .frame(width: 100.5, height: 128.54)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 230.51)
            .padding(.top, 69.2)
            .accessibilityHidden(true)   // 장식 — 안내는 아래 문구가 읽어준다

        // Figma Vector 300: 마스코트 아래에서 문구로 내려온다.
        Image(dsImage: "homeGuideMascotArrow")
            .resizable()
            .frame(width: 30.09, height: 55.48)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 116.82)
            .padding(.top, 118.52)
            .accessibilityHidden(true)

        Text("방 뱃지와 토끼를 클릭하면\n방을 변경할 수 있어요")
            .mhTypography(.body1NormalBold)
            .foregroundStyle(.mhLabelNormal)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 168, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 51)
            .padding(.top, 180)
            .accessibilityIdentifier("Home.guide.roomChangeCopy")
    }

    // MARK: - 카드 스와이프 안내

    /// 맨 앞 카드 위에 얹히는 손 그래픽 + 문구. 카드가 화면 가운데 고정이라 이 묶음도 가운데 정렬이다
    /// (시안에서도 손·문구·카드의 중심이 모두 187.5 로 같다).
    private var swipeGuide: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Image(dsImage: "homeGuideSwipeArcs")
                    .resizable()
                    .frame(width: 82.93, height: 40.97)
                Image(dsImage: "homeGuideHand")
                    .resizable()
                    .frame(width: 53, height: 63.74)
            }
            .accessibilityHidden(true)   // 장식 — 안내는 아래 문구가 읽어준다

            Text("좌우로 스와이프하며\n카드를 탐색해 보세요.")
                .mhTypography(.body1NormalBold)
                .foregroundStyle(.mhStaticBlack)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("Home.guide.swipeCopy")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 442)   // Figma: 손 그래픽 상단 486 − 상태바 44
    }

    // MARK: - 하단 CTA

    /// "시작하기" — 시안에서 이 영역이 탭바를 통째로 덮는다(sticky 배경이 불투명).
    private var actionArea: some View {
        MHActionArea(main: .init("시작하기", action: onStart), sticky: true)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .accessibilityIdentifier("Home.guide.actionArea")
    }
}

// MARK: - 가이드 딤

extension View {
    /// 가이드 딤 뒤로 물러나는 요소. 시안의 `backdrop-blur 6 + white 80%`(Figma `dimd`)를
    /// 요소 쪽에서 재현한다 — 흰 딤을 요소 **위**에 덮는 대신 요소를 흐리고 20% 로 낮춘다.
    ///
    /// 그래야 하는 이유: 배경에는 같은 딤이 이미 깔려 있어(``HomeContentView`` 의 배경 워시)
    /// "흰 배경 위 20% 요소" = "요소 위 흰색 80%" 로 결과가 같은데, 요소마다 오버레이를 덮으면
    /// blur 가 프레임 밖으로 번지는 만큼 오버레이가 못 덮어 테두리에 선명한 띠가 남는다.
    func homeGuideDimmed(_ isDimmed: Bool) -> some View {
        blur(radius: isDimmed ? 6 : 0)
            .opacity(isDimmed ? 0.2 : 1)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.mhBackgroundNormalAlternative
        HomeGuideOverlay(onStart: {})
    }
}
