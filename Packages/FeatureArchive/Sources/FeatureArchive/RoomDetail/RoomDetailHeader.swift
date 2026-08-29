import DesignSystem
import ProfileSetupUI
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
            MHAvatarStack(AvatarArt.images(for: room.memberAvatarIDs), onAdd: onAddMember)
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                MHCircleIconButton(icon: .moreVertical, accessibilityLabel: "더보기", action: onMore)
                    .accessibilityIdentifier("RoomDetail.more")
                    // 드롭다운은 시트 밖(껍데기)이 그린다 — 이 버튼 위치를 기준점으로 올려 보낸다.
                    .roomDetailMoreMenuAnchor()
                MHCircleIconButton(icon: .close, accessibilityLabel: "닫기", action: onClose)
                    .accessibilityIdentifier("RoomDetail.close")
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }

    private var roomInfo: some View {
        MHRoomHeader(
            title: room.title,
            memo: room.memo.isEmpty ? nil : room.memo,
            count: room.locationCountText
        )
        .accessibilityIdentifier("RoomDetail.header")
    }
}

#Preview {
    RoomDetailHeader(room: .sample, onAddMember: {}, onMore: {}, onClose: {})
}
