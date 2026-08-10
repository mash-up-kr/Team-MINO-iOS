import DesignSystem
import SwiftUI

/// 튜토리얼에서 "공유 버튼 누르기"를 연습시키기 위한 **가짜 SNS 게시물 카드**. Figma `Photo Insta`(node 2314:58861).
///
/// 실제 Instagram 과 연동되지 않는 목업이라 서체·아이콘·색이 우리 디자인 시스템을 따르지 않는다.
/// SNS 화면처럼 보이는 것이 목적이므로 SF(시스템 폰트)와 SF Symbols 를 쓰고, 카드 테두리·공유 버튼처럼
/// **디자인이 우리 토큰을 지정한 부분만** `MHTypography`/`Color.mh*`/`MHIcon` 을 쓴다.
///
/// `shareAccessory` 는 공유 버튼 **바로 위**에 얹히는 슬롯이다(툴팁 앵커). 버튼 위치를 아는 건 이 카드뿐이라
/// 배치 책임을 밖으로 넘기지 않는다.
/// Figma 가 토큰 대신 hex 로 박아둔 목업 전용 색 — SNS 앱을 흉내 내는 값이라 DS 토큰으로 승격하지 않는다.
private enum MockColor {
    static let activeDot = Color(red: 0 / 255, green: 152 / 255, blue: 252 / 255)      // #0098FC
    static let feedBackground = Color(red: 244 / 255, green: 244 / 255, blue: 254 / 255)  // #F4F4FE
}

struct MockInstagramPost<ShareAccessory: View>: View {
    var onTapShare: () -> Void = {}
    @ViewBuilder var shareAccessory: () -> ShareAccessory

    var body: some View {
        VStack(spacing: 4) {
            profileRow
            feedImage
            bottomInfo
        }
        .padding(.vertical, 12)
        .background(Color.mhBackgroundElevatedNormal)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.mhLineSolidNeutral, lineWidth: 1.5)
        }
    }

    // MARK: - Profile

    private var profileRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: 7) {
                // Figma 원본도 프로필 이미지가 placeholder(단색 채움)다 — 목업이라 사진을 두지 않는다.
                Circle()
                    .fill(Color.mhPrimaryNormal)
                    .frame(width: 31.5, height: 31.5)

                VStack(alignment: .leading, spacing: 1) {
                    Text("GGUK").font(.system(size: 12, weight: .medium))
                    Text("Arneo").font(.system(size: 10))
                }
                .foregroundStyle(Color.mhPrimaryNormal)
            }
            Spacer(minLength: 0)
            Image(MHIcon.moreHorizontal)
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundStyle(Color.mhPrimaryNormal)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        // 목업 전용 프로필(가짜 이름·아이콘) — 학습 대상(공유 버튼)이 아니라 탭도 안 된다.
        .accessibilityHidden(true)
    }

    // MARK: - Feed image

    // 게시물 사진 자리. 실제 사진이 아니라 투명 배경 일러스트라 연보라 판 위에 여백을 두고 얹는다.
    private var feedImage: some View {
        Image("tutorialSamplePost", bundle: .module)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .frame(height: 270)
            .background(MockColor.feedBackground)
            .clipped()
            .accessibilityHidden(true)
    }

    // MARK: - Bottom

    private var bottomInfo: some View {
        VStack(spacing: 6) {
            pageIndicator
            actionRow
            caption
        }
        .padding(.top, 8)
        .padding(.horizontal, 20)
    }

    // 캐러셀 인디케이터(첫 장 활성) — 36×6 안에 6pt 점 4개.
    private var pageIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index == 0 ? MockColor.activeDot : Color.mhFillNormal)
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }

    private var actionRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                mockIcon("tutorialIconHeart")
                mockIcon("tutorialIconComment")
                shareButton
            }
            .foregroundStyle(Color.mhPrimaryNormal)

            Spacer(minLength: 0)

            mockIcon("tutorialIconBookmark")
                .foregroundStyle(Color.mhPrimaryNormal)
        }
        .frame(height: 28, alignment: .center)
        .padding(.bottom, 4)
    }

    // SNS 앱 아이콘은 SF Symbols 로 근사하면 모양이 눈에 띄게 달라(댓글·북마크) Figma 벡터를 그대로 쓴다.
    // 단색 template 이라 위에서 건 foregroundStyle 이 그대로 먹는다.
    private func mockIcon(_ name: String) -> some View {
        Image(name, bundle: .module)
            .resizable()
            .renderingMode(.template)
            .frame(width: 24, height: 24)
            .accessibilityHidden(true)
    }

    // 이 화면의 학습 대상. Figma `Menu/Resource/Action Area/Trailing Content/Icon Button`(36×36).
    // 원형 배경은 아이콘 에셋에 굽지 않고 `Circle().fill()` 로 그린다 — DS 에 원형 아이콘 버튼
    // 컴포넌트가 아직 없어 `MHAvatarStack` 의 + 버튼·`RoomDetailCircleIconButton` 도 같은 방식이다.
    // 아이콘 20.25pt 는 Figma 벡터 실측값이다(32pt 버튼의 18pt 아이콘이 1.125배로 들어가 있다).
    // SNS 앱을 흉내 내는 목업이라 색도 Figma 값 고정이다(DS 토큰으로 틴트하지 않는다).
    private var shareButton: some View {
        Button(action: onTapShare) {
            Image(MHIcon.sendFill)
                .resizable()
                .scaledToFit()
                .frame(width: 20.25, height: 20.25)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(.black))
        }
        .accessibilityLabel("공유")
        .accessibilityIdentifier("TutorialShareGuide.shareButton")
        // 툴팁 오버레이는 식별자를 붙인 뒤에 얹는다 — 먼저 얹으면 버튼의 식별자를 물려받아
        // 같은 id 가 둘이 되고 QA 자동화의 `tap --id` 가 다중 매치로 실패한다.
        .overlay(alignment: .top) { shareAccessory() }
    }

    /// 캡션 자리. Figma 가 실제 문구 대신 placeholder 바 2개(295×20, 간격 12)로 바꿨다 —
    /// 튜토리얼의 학습 대상은 공유 버튼이라 읽을거리로 시선을 끌지 않으려는 의도로 보인다.
    private var caption: some View {
        VStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.mhFillNormal)
                    .frame(height: 20)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

extension MockInstagramPost where ShareAccessory == EmptyView {
    init(onTapShare: @escaping () -> Void = {}) {
        self.init(onTapShare: onTapShare, shareAccessory: { EmptyView() })
    }
}

#Preview {
    MockInstagramPost()
        .padding(20)
        .background(Color.mhBackgroundNormalNormal)
}
