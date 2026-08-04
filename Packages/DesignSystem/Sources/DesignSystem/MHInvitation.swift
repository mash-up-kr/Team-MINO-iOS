import SwiftUI

/// 봉투에 담긴 모임 초대장. Figma `invitation`(node 16108:23382, iOS variant).
///
/// ``MHInvitationCard`` 를 편지 봉투 그래픽 위에 얹어, 카드가 봉투에서 꺼내진 모습을 연출한다.
/// 봉투 뒤 삼각 플랩 → 카드 → 봉투 앞면(V접힘) 순으로 쌓인다.
///
/// ```swift
/// MHInvitation(
///     thumbnailColor: .pink,
///     title: "5월의 약속 : 우리끼리",
///     description: "우리 모임 장소 픽업 공간.",
///     members: [img1, img2, img3],
///     placeCount: 1200
/// )
/// ```
public struct MHInvitation: View {
    private let thumbnailColor: MHRoomThumbnailColor
    private let title: String
    private let description: String
    private let members: [Image?]
    private let placeCount: Int

    // Figma iOS variant 기준 비율(297×311).
    private let designWidth: CGFloat = 297
    private let designHeight: CGFloat = 311

    public init(
        thumbnailColor: MHRoomThumbnailColor = .pink,
        title: String,
        description: String,
        members: [Image?] = [],
        placeCount: Int
    ) {
        self.thumbnailColor = thumbnailColor
        self.title = title
        self.description = description
        self.members = members
        self.placeCount = placeCount
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Image("envelopeBack", bundle: .module)
                .resizable().scaledToFit()
                .frame(width: designWidth)
                .offset(y: 60)

            MHInvitationCard(
                thumbnailColor: thumbnailColor,
                title: title,
                description: description,
                members: members,
                placeCount: placeCount
            )
            .frame(width: 256)
            .overlay(alignment: .bottom) {
                // 3) 카드 하단 그림자 가림 (카드 위, 봉투 앞면 아래)
                Rectangle()
                    .fill(Color.mhBackgroundNormalNormal)
                    .frame(height: 60)
                    .offset(y: 50)
            }

            Image("envelopeFront", bundle: .module)
                .resizable().scaledToFit()
                .frame(width: designWidth)
                .offset(y: 149)
        }
        .frame(width: designWidth, height: designHeight)
    }
}

#Preview("MHInvitation") {
    MHInvitation(
        thumbnailColor: .pink,
        title: "5월의 약속 : 우리끼리",
        description: "우리 모임 장소 픽업 공간.",
        members: [nil, nil, nil],
        placeCount: 1200
    )
    .padding()
}
