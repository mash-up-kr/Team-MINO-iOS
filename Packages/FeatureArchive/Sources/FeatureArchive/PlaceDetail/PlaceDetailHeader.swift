import DesignSystem
import SwiftUI

/// 헤더 상단 여백. **시트 단계마다 다르다** — 시안을 375×812 PNG 로 받아 픽셀로 실측한 값이다.
///
/// | 단계 | 시안 | 기준선 | 헤더 첫 줄(닫기 버튼 40pt 상자) 윗끝 |
/// |---|---|---|---|
/// | half | `005-1` `2792:142415` | 시트 흰 면 윗끝 y=441 | y=471 → **30** |
/// | full | `005-2-1` `2792:142205` | 상태바 아래 y=54 | `Frame 303` 의 `Button/Icon/Outlined` y=12 → **12** |
/// | full 축소 | `005-2-2` `2792:142297` | 상태바 아래 y=54 | `Frame 37` 의 같은 버튼 y=12 → **12** |
///
/// half 의 30 은 `MHBottomSheet` 그래버 프레임(30pt)이 통째로 메운다(캡슐이 시트 윗끝에서 13pt —
/// 시안 실측과 일치). 그래서 헤더가 더 얹을 값은 **0** 이다. full 은 그래버가 없어
/// (`MHBottomSheet` 가 full 에서 뺀다) 헤더가 12 를 직접 낸다.
///
/// **왜 `detent` 를 받는가.** 대안은 ① 그래버 높이를 시트가 environment 로 알려주고 헤더가 빼는 것,
/// ② `hasGrabber: Bool` 을 받는 것이었다. ①은 성립하지 않는다 — 두 단계의 시안 값(30/12)이
/// "고정값 − 그래버 높이" 꼴로 유도되지 않아, 그래버 높이를 알아도 여백이 나오지 않는다(두 단계가
/// 그냥 서로 다른 스펙이다). ②는 "full 에는 그래버가 없다" 는 시트 내부 규칙을 피쳐가 한 번 더
/// 베껴 적는 것이라, 이미 `PlaceDetailView` 가 들고 있는 detent 를 그대로 넘겨 출처를 하나로 둔다.
enum PlaceDetailHeaderMetrics {
    /// full 에서 헤더가 직접 내는 값.
    static let fullTopInset: CGFloat = 12

    static func topInset(for detent: MHBottomSheetDetent) -> CGFloat {
        switch detent {
        case .low, .medium: 0   // 그래버 프레임(30pt)이 시안의 30 을 이미 채웠다
        case .full: fullTopInset
        }
    }
}

struct PlaceDetailHeader: View {
    let place: PlaceDetailPlace
    /// 상단 여백이 단계마다 다르다 — ``PlaceDetailHeaderMetrics`` 참조.
    let detent: MHBottomSheetDetent
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
        .padding(.top, PlaceDetailHeaderMetrics.topInset(for: detent))
        .padding(.bottom, 18)
    }

    /// ② 해당 장소를 공유한 사람. 시안에는 아바타만 있고 닉네임 자리가 없어, 이름은
    /// 접근성 라벨로만 읽힌다.
    ///
    /// 얼굴은 ``ArchiveAvatarArt`` 가 프리셋 번호로 고른다 — 번호↔색 계약이 확정되면 그 파일만
    /// 갈아끼우면 아카이브의 모든 프로필 자리가 함께 옮겨 간다.
    private var sharerAvatar: some View {
        MHAvatar(place.sharer.map { ArchiveAvatarArt.image(for: $0.avatarID) }, size: 32)
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
        .padding(.top, PlaceDetailHeaderMetrics.topInset(for: detent))
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
        detent: .full,
        isCollapsed: false,
        canOpenSource: true,
        onOpenMap: {}, onOpenSource: {}, onShare: {}, onClose: {}
    )
}

#Preview("축소") {
    PlaceDetailHeader(
        place: .sample,
        detent: .full,
        isCollapsed: true,
        canOpenSource: true,
        onOpenMap: {}, onOpenSource: {}, onShare: {}, onClose: {}
    )
}

#Preview("출처 없음") {
    PlaceDetailHeader(
        place: .sample,
        detent: .medium,
        isCollapsed: false,
        canOpenSource: false,
        onOpenMap: {}, onOpenSource: {}, onShare: {}, onClose: {}
    )
}
