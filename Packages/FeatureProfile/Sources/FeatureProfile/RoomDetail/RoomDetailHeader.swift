import DesignSystem
import SwiftUI

/// 시트 최상단 — 멤버 pill·더보기·닫기 줄과 `Header_Room`(제목/메모/장소 수).
struct RoomDetailHeader: View {
    let room: RoomDetailRoom
    let onAddMember: () -> Void
    let onMore: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            actionRow
            roomInfo
        }
        .background(Color.mhBackgroundNormalNormal)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.mhLineSolidAlternative)
                .frame(height: 1)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 0) {
            RoomDetailMemberPill(memberCount: room.memberCount, onAdd: onAddMember)
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                RoomDetailCircleIconButton(icon: .moreVertical, accessibilityLabel: "더보기", action: onMore)
                RoomDetailCircleIconButton(icon: .close, accessibilityLabel: "닫기", action: onClose)
                    .accessibilityIdentifier("RoomDetail.close")
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }

    private var roomInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(room.title)
                    .mhTypography(.title3Bold)
                    .foregroundStyle(.mhLabelStrong)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(room.memo)
                    .mhTypography(.label1NormalRegular)
                    .foregroundStyle(.mhLabelNeutral)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RoomDetailMetric(
                icon: .locationFill,
                text: room.locationCountText,
                typography: .label1NormalRegular
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("RoomDetail.header")
    }
}

#Preview {
    RoomDetailHeader(room: .sample, onAddMember: {}, onMore: {}, onClose: {})
}
