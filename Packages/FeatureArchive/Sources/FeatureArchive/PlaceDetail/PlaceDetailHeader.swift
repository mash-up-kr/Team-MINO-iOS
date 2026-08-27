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
                MHAvatar(nil, size: 32)
                MHContentBadge(
                    "저장한지 \(place.savedDays)일째",
                    size: .medium,
                    color: .mhAccentForegroundRedOrange
                )
            }
            Spacer(minLength: 8)
            closeButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 18)
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
        .frame(height: isCollapsed ? 52 : 64)
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
