import SwiftUI

// MARK: - Home Card

/// 홈에서 쓰는 장소 카드. Figma `Card_Home`(node 15852:88604).
///
/// 상단에 작성자 아바타 + 추천 이유 뱃지(강조색) + 더보기 버튼, 그 아래 제목·주소, 마지막에 사진 2장을
/// 나란히 보여준다. Figma 의 4개 variant 는 뱃지의 문구·강조색만 다르므로 `badgeText`·`badgeColor` 로 받는다
/// (예: 클릭률순=Light Blue, 코멘트순=Pink, 저장겹침=Red Orange, 기본=Lime).
///
/// ```swift
/// MHHomeCard(
///     avatar: Image("me"), badgeText: "친구들이 많이 본 곳", badgeColor: .mhAccentForegroundLightBlue,
///     title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10", images: [img1, img2]
/// ) { openMore() }
/// ```
public struct MHHomeCard: View {
    private let avatar: Image?
    private let badgeText: String
    private let badgeColor: Color
    private let title: String
    private let address: String
    private let images: [Image]
    private let onMore: (() -> Void)?

    public init(
        avatar: Image?,
        badgeText: String,
        badgeColor: Color,
        title: String,
        address: String,
        images: [Image],
        onMore: (() -> Void)? = nil
    ) {
        self.avatar = avatar
        self.badgeText = badgeText
        self.badgeColor = badgeColor
        self.title = title
        self.address = address
        self.images = images
        self.onMore = onMore
    }

    public var body: some View {
        VStack(spacing: 16) {                          // Figma: gap base(16)
            VStack(spacing: 12) {                       // Figma: gap md(12)
                HStack(spacing: 0) {
                    HStack(spacing: 8) {                // Figma: gap sm(8)
                        MHAvatar(avatar, size: 32)
                        MHContentBadge(badgeText, variant: .solid, size: .medium, color: badgeColor)
                    }
                    Spacer(minLength: 0)
                    moreButton
                }
                info
            }
            imageGrid
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.mhBackgroundNormalNormal))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.mhBackgroundNormalAlternative, lineWidth: 1))
    }

    // 제목 + 주소. 각각 한 줄 말줄임.
    private var info: some View {
        VStack(alignment: .leading, spacing: 2) {      // Figma: gap xxs(2)
            line(title, .body1NormalBold, .mhLabelNormal)
            line(address, .label2Regular, .mhLabelAlternative)
        }
        .padding(.horizontal, 4)                        // Figma: px4
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func line(_ string: String, _ token: MHTypography, _ color: Color) -> some View {
        Text(string)
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(color)
            .mhTypography(token)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 더보기(⋮) 버튼. Figma: Background/Normal/Alternative 원 + moreVertical 18pt, p7=32pt.
    private var moreButton: some View {
        Button { onMore?() } label: {
            Image(MHIcon.moreVertical)
                .resizable().scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(.mhLabelAlternative)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.mhBackgroundNormalAlternative))
        }
        .buttonStyle(MHHomeCardMoreStyle())
    }

    // 사진 2장 나란히(각 가용폭 절반, 높이 184, radius 16, fill+crop).
    private var imageGrid: some View {
        HStack(spacing: 8) {
            ForEach(Array(images.prefix(2).enumerated()), id: \.offset) { _, image in
                image
                    .resizable().scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 184)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

// MARK: - ButtonStyle (더보기 press)

// Figma `Interaction/Strong`(Label/Normal) — 눌림 시 원 위에 옅게 덮는다.
struct MHHomeCardMoreStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                if configuration.isPressed {
                    Circle().fill(Color.mhLabelNormal.opacity(0.09)).frame(width: 32, height: 32)
                }
            }
    }
}

#Preview("MHHomeCard") {
    MHHomeCard(
        avatar: nil,
        badgeText: "친구들이 많이 본 곳",
        badgeColor: .mhAccentForegroundLightBlue,
        title: "레이어스튜디오 10",
        address: "서울 성동구 상원4길 10",
        images: []
    ) { }
    .frame(width: 335)
    .padding()
}
