import DesignSystem
import SwiftUI

struct PlaceDetailHeader: View {
    let place: PlaceDetailPlace
    let isCollapsed: Bool
    /// 출처 링크가 확보됐는가. 없으면 "원문보기" 는 눌러도 갈 곳이 없어 비활성으로 둔다.
    let canOpenSource: Bool
    let onOpenMap: () -> Void
    let onOpenSource: () -> Void
    let onShare: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isCollapsed {
                collapsedTitleRow
            } else {
                ownerRow
                titleRow
            }
            actionRow
        }
        .background(Color.mhBackgroundNormalNormal)
    }

    private var ownerRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                sharerAvatar
                categoryBadge
            }
            Spacer(minLength: 8)
            closeButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    /// ② 해당 장소를 공유한 사람. 시안에는 아바타만 있고 닉네임 자리가 없어, 이름은
    /// 접근성 라벨로만 읽힌다.
    ///
    /// 그림은 아직 익명이다 — 서버가 아바타를 두 가지로 표현하는데(방 멤버는 `avatar.id: Int`,
    /// 프로필 API 는 `avatar.color: String`) 그 둘의 관계가 문서에 없다. 번호를 캐릭터 그리드
    /// 순번으로 **가정하면 남의 얼굴이 뜨고, 틀렸다는 걸 아무도 바로 알아채지 못한다.**
    /// 계약이 확인되면 `AvatarPalette`(색↔캐릭터를 잇는 유일한 표)를 통해 잇는다.
    private var sharerAvatar: some View {
        MHAvatar(nil, size: 32)
            .accessibilityElement()
            .accessibilityLabel(place.sharer.map { "\($0.nickname) 님이 저장" } ?? "저장한 사람 정보 없음")
            .accessibilityIdentifier("PlaceDetail.sharer")
    }

    /// ③ 장소분류. 홈 카드가 다는 큐레이션 라벨을 같은 문구·색으로 따라간다.
    private var categoryBadge: some View {
        let badge = PlaceDetailCategoryBadge.of(place.category)
        return MHContentBadge(badge.text, size: .medium, color: badge.color)
            .accessibilityIdentifier("PlaceDetail.category")
    }

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name)
                .mhTypography(.title3Bold)
                .foregroundStyle(.mhLabelStrong)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityIdentifier("PlaceDetail.title")
            Text(place.address)
                .mhTypography(.label1NormalRegular)
                .foregroundStyle(.mhLabelNeutral)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var collapsedTitleRow: some View {
        HStack(spacing: 8) {
            Text(place.name)
                .mhTypography(.title3Bold)
                .foregroundStyle(.mhLabelStrong)
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityIdentifier("PlaceDetail.title")
            Spacer(minLength: 0)
            closeButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    private var closeButton: some View {
        RoomDetailCircleIconButton(icon: .close, accessibilityLabel: "닫기", action: onClose)
            .accessibilityIdentifier("PlaceDetail.close")
    }

    /// ⑬ 액션 행 높이. 시안은 **축소·확장 두 헤더에 같은 값**을 썼다 — 005-2-2 축소 헤더의
    /// `Frame 295`(`2792:142299`)와 005-2-1 확장 헤더의 `Frame 295`(`2792:185141`)가 둘 다
    /// h=64 이고, 안의 버튼이 y=12·h=40 으로 위아래 12 씩 남긴다. 축소될 때 줄어드는 건
    /// 제목 영역뿐이라 여기서 단계를 나누지 않는다.
    private static let actionRowHeight: CGFloat = 64

    private var actionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                MHButton("장소보기", size: .medium, leadingIcon: .location, action: onOpenMap)
                    .accessibilityIdentifier("PlaceDetail.openMap")
                MHButton(
                    "원문보기",
                    variant: .outlined,
                    color: .assistive,
                    size: .medium,
                    leadingIcon: .documentText,
                    action: onOpenSource
                )
                .disabled(!canOpenSource)
                .accessibilityIdentifier("PlaceDetail.openSource")
                MHButton(
                    "다른방에 공유",
                    variant: .outlined,
                    color: .assistive,
                    size: .medium,
                    leadingIcon: .persons,
                    action: onShare
                )
                .accessibilityIdentifier("PlaceDetail.share")
            }
            .padding(.horizontal, 20)
        }
        .frame(height: Self.actionRowHeight)
    }
}

#Preview("확장") {
    PlaceDetailHeader(
        place: .sample,
        isCollapsed: false,
        canOpenSource: true,
        onOpenMap: {}, onOpenSource: {}, onShare: {}, onClose: {}
    )
}

#Preview("축소") {
    PlaceDetailHeader(
        place: .sample,
        isCollapsed: true,
        canOpenSource: true,
        onOpenMap: {}, onOpenSource: {}, onShare: {}, onClose: {}
    )
}

#Preview("출처 없음") {
    PlaceDetailHeader(
        place: .sample,
        isCollapsed: false,
        canOpenSource: false,
        onOpenMap: {}, onOpenSource: {}, onShare: {}, onClose: {}
    )
}
