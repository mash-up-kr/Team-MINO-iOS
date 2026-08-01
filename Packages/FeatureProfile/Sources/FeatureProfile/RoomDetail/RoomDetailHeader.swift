import DesignSystem
import SwiftUI

/// 방 상세 시트 최상단 — 멤버 pill·더보기·닫기 줄과 `Header_Room`(제목/메모/장소 수).
/// peek 단계에서 보이는 유일한 영역이라 시트 높이(`lowFraction`) 산정 기준이기도 하다.
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

    // Figma 1672:66177 — h60, px20, 좌우 끝 정렬
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

    // Figma Header_Room(15852:88517) — pt12 pb20 px20, gap10
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
