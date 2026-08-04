import DesignSystem
import SwiftUI

/// 튜토리얼에서 "공유 버튼 누르기"를 연습시키기 위한 **가짜 SNS 게시물 카드**. Figma `Photo Insta`(node 1529:84576).
///
/// 실제 Instagram 과 연동되지 않는 목업이라 서체·아이콘·색이 우리 디자인 시스템을 따르지 않는다.
/// SNS 화면처럼 보이는 것이 목적이므로 SF(시스템 폰트)와 SF Symbols 를 쓰고, 카드 테두리·공유 버튼처럼
/// **디자인이 우리 토큰을 지정한 부분만** `MHTypography`/`Color.mh*`/`MHIcon` 을 쓴다.
///
/// `shareAccessory` 는 공유 버튼 **바로 위**에 얹히는 슬롯이다(툴팁 앵커). 버튼 위치를 아는 건 이 카드뿐이라
/// 배치 책임을 밖으로 넘기지 않는다.
/// Figma 가 토큰 대신 hex 로 박아둔 목업 전용 색 — SNS 앱을 흉내 내는 값이라 DS 토큰으로 승격하지 않는다.
private enum MockColor {
    static let hashtag = Color(red: 62 / 255, green: 169 / 255, blue: 229 / 255)  // #3EA9E5
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
                .strokeBorder(Color.mhPrimaryNormal, lineWidth: 1.5)
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
    }

    // MARK: - Feed image

    private var feedImage: some View {
        Image("tutorialSamplePost", bundle: .module)
            .resizable()
            .scaledToFill()
            .frame(height: 319)
            .clipped()
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
                    .fill(index == 0 ? MockColor.hashtag : Color.mhFillNormal)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "heart")
                    .font(.system(size: 22, weight: .light))
                Image(systemName: "bubble.right")
                    .font(.system(size: 20, weight: .light))
                    .scaleEffect(x: -1)          // Instagram 말풍선은 꼬리가 왼쪽 아래
                shareButton
            }
            .foregroundStyle(Color.mhPrimaryNormal)

            Spacer(minLength: 0)

            Image(systemName: "bookmark")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.mhPrimaryNormal)
        }
        .frame(height: 28, alignment: .center)
        .padding(.bottom, 4)
    }

    // 이 화면의 학습 대상. Figma `Button/Icon/Solid` + `Icon/Normal/Send`(검정 원 36 / 아이콘 20.25).
    private var shareButton: some View {
        Button(action: onTapShare) {
            Image(MHIcon.send)
                .resizable()
                .frame(width: 20.25, height: 20.25)
                .foregroundStyle(Color.mhStaticWhite)
                .padding(7.875)
                .background(Color.mhPrimaryNormal, in: Circle())
        }
        .overlay(alignment: .top) { shareAccessory() }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 6) {
            (Text("GGUK").font(.system(size: 12, weight: .medium))
                + Text("님 외 여러명이 좋아합니다").font(.system(size: 12)))
                .foregroundStyle(Color.mhLabelNormal)

            (Text("GGUK ").font(.system(size: 12, weight: .medium))
                + Text("꾸덕한 크림과 버섯의 깊은 풍미.\n가끔은 이런 한 그릇이 가장 큰 위로가 돼요.🍴\n").font(.system(size: 12))
                + Text("#Proud").font(.system(size: 12)).foregroundColor(MockColor.hashtag))
                .foregroundStyle(Color.mhLabelNormal)

            Text("5일 전")
                .font(.system(size: 11))
                .foregroundStyle(Color.mhLabelNeutral)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
