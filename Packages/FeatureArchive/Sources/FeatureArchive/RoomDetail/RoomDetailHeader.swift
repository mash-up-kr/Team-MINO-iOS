import DesignSystem
import Domain
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
            // `+` 의 식별자·라벨은 `MHAvatarStack` 이 버튼 자신에 붙인다(`MHAvatarStack.add`) —
            // pill 에 걸면 아바타까지 전파돼 자동화가 `+` 를 지목할 수 없다.
            //
            // 개인방에는 `+` 를 달지 않는다 — 초대 불가라 누를 것이 없다(``RoomDetailRoom/isPersonal``).
            MHAvatarStack(
                AvatarPalette.images(of: room.memberAvatarColors),
                trailing: room.isPersonal ? MHAvatarStackTrailing.none : .add(action: onAddMember)
            )
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                // 개인방에는 더보기 자체가 없다 — 편집은 방장 전용, 나가기는 개인방 금지라
                // 항목이 하나도 남지 않는다(``RoomDetailRoom/isPersonal``).
                if !room.isPersonal {
                    MHCircleIconButton(icon: .moreVertical, accessibilityLabel: "더보기", action: onMore)
                        .accessibilityIdentifier("RoomDetail.more")
                        // 드롭다운은 시트 밖(껍데기)이 그린다 — 이 버튼 위치를 기준점으로 올려 보낸다.
                        .roomDetailMoreMenuAnchor()
                }
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

#Preview("공동방") {
    RoomDetailHeader(room: .sample, onAddMember: {}, onMore: {}, onClose: {})
}

// 개인방 — `+`·`⋮` 가 빠지고 닫기만 남는다.
#Preview("개인방") {
    RoomDetailHeader(room: .personalSample, onAddMember: {}, onMore: {}, onClose: {})
}
