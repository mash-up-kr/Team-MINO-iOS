import SwiftUI

// MARK: - Invitation Card

/// 모임 초대 카드. Figma `invitation_card`(node 16108:23255).
///
/// 상단에 방 대표 썸네일(``MHRoomThumbnail``), 중간에 모임 이름·설명,
/// 하단에 멤버 아바타 그룹과 장소 수를 보여준다. 아바타는 최대 5개까지만 표시한다.
///
/// ```swift
/// MHInvitationCard(
///     thumbnailColor: .pink,
///     title: "5월의 약속 : 우리끼리",
///     description: "우리 모임 장소 픽업 공간.",
///     members: [img1, img2, img3],
///     placeCount: 1200
/// )
/// ```
public struct MHInvitationCard: View {
    private let thumbnailColor: MHRoomThumbnailColor
    private let title: String
    private let description: String
    private let members: [Image?]
    private let placeCount: Int

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
        self.members = Array(members.prefix(5))
        self.placeCount = placeCount
    }

    public var body: some View {
        VStack(spacing: 12) {
            MHRoomThumbnail(color: thumbnailColor, size: 80)
            VStack(spacing: 8) {
                info
                bottomRow
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.mhBackgroundNormalNormal))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.mhBackgroundNormalAlternative, lineWidth: 1))
        .mhShadow(.small, cornerRadius: 16)
    }

    // 제목 + 설명. 각각 한 줄 말줄임, 중앙 정렬.
    private var info: some View {
        VStack(spacing: 2) {
            Text(title)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.mhLabelNormal)
                .mhTypography(.body1NormalBold)
            Text(description)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(.mhLabelAlternative)
                .mhTypography(.label2Regular)
        }
        .frame(maxWidth: .infinity)
    }

    // 멤버 아바타 그룹 + 장소 수. 고정 간격으로 나란히 놓는다.
    private var bottomRow: some View {
        HStack(spacing: 8) {
            if !members.isEmpty {
                MHAvatarGroup(members, variant: .person, size: .xSmall)
            }
            Text(countText)
                .lineLimit(1)
                .mhTypography(.label2Medium)
                .foregroundStyle(.mhLabelAlternative)
        }
        .frame(maxWidth: .infinity)
    }

    // 999 초과는 999+ 로 절단(Figma).
    private var countText: String {
        placeCount > 999 ? "장소 999+개" : "장소 \(placeCount)개"
    }
}

#Preview("MHInvitationCard") {
    VStack(spacing: 16) {
        MHInvitationCard(
            thumbnailColor: .pink,
            title: "5월의 약속 : 우리끼리",
            description: "우리 모임 장소 픽업 공간.",
            members: [nil, nil, nil],
            placeCount: 1200
        )
        .frame(width: 260)

        MHInvitationCard(
            thumbnailColor: .violet,
            title: "5월의 약속 : 우리끼리",
            description: "우리 모임 장소 픽업 공간.",
            members: [nil, nil, nil, nil, nil, nil, nil],
            placeCount: 5
        )
        .frame(width: 200)
    }
    .padding()
}
