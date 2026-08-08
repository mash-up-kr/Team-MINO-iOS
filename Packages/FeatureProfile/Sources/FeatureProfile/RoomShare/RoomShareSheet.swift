import DesignSystem
import SwiftUI

/// 장소를 다른 방에 공유하는 바텀시트. Figma `004-2-2_다른 방에 공유 클릭`(`1672:73592`).
///
/// 시안이 딤(`Material/Dimmer`)을 동반한 모달이라 `MHBottomSheet`(딤 없는 비모달 3-detent)이 아니라
/// SwiftUI 네이티브 `.sheet` + `presentationDetents` 위에 얹는다. 띄우는 쪽은 `ProfileTabView`.
struct RoomShareSheet: View {
    /// `presentationDetents(.height(_:))` 에 넘길 값.
    ///
    /// 시안 시트 높이 500 은 홈 인디케이터(34)까지 포함한 값인데, iOS 의 `.height` 는 하단 안전영역
    /// **위쪽** 높이라 그만큼 뺀다(시뮬레이터 실측: 500 을 주면 화면상 534 가 나온다).
    /// 홈 인디케이터가 없는 기기에서는 시트가 34pt 짧아지지만 리스트가 그만큼 줄 뿐이라 무해하다.
    static let detentHeight: CGFloat = 500 - 34

    let location: RoomDetailLocation
    let rooms: [RoomShareRoom]
    let onClose: () -> Void
    let onSubmit: (Set<RoomShareRoom.ID>) -> Void

    @State private var selection = RoomShareSelection()

    var body: some View {
        VStack(spacing: 0) {
            grabber
            locationHeader
            newRoomRow
            dividerRow
            roomList
            // safeArea: false — 시트가 이미 홈 인디케이터 높이를 확보한다. 켜 두면 34pt 가 이중으로 잡혀
            // 시트가 시안(500)보다 그만큼 커진다.
            MHActionArea(main: .init("공유하기") { onSubmit(selection.ids) }, safeArea: false)
                .disabled(!selection.canSubmit)
                .accessibilityIdentifier("RoomShare.submitButton")
        }
        .background(.mhBackgroundElevatedNormal)
        .accessibilityIdentifier("RoomShare.sheet")
    }

    // 그래버 — h30(py12) 안에 38×4 바. Figma `1672:73594`.
    private var grabber: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.mhFillNormal)
            .frame(width: 38, height: 4)
            .frame(height: 30)
    }

    // 공유할 장소 — 썸네일 46 + 제목/메모 + 닫기. Figma `1672:73596`.
    private var locationHeader: some View {
        HStack(spacing: 14) {
            RoomShareLocationThumbnail()

            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .mhTypography(.body1NormalBold)
                    .foregroundStyle(.mhLabelNormal)
                    .lineLimit(1)
                Text(location.address)
                    .mhTypography(.label2Medium)
                    .foregroundStyle(.mhLabelAlternative)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RoomDetailCircleIconButton(icon: .close, accessibilityLabel: "닫기", action: onClose)
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }

    // 새 방 만들기 — Figma `1672:73605`. 진입 화면(공동방 만들기)이 아직 없어 표시만 한다.
    private var newRoomRow: some View {
        HStack {
            Button {
                // TODO: 공동방 만들기 화면이 생기면 여기서 진입한다.
            } label: {
                HStack(spacing: 4) {
                    Image(.plus)
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text("새 방 만들기")
                        .mhTypography(.body1NormalBold)
                }
                .foregroundStyle(.mhLabelAlternative)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("RoomShare.newRoomButton")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // 구분선 — h12 컨테이너 안 1px. Figma `1672:73606`.
    private var dividerRow: some View {
        Rectangle()
            .fill(.mhLineNormalNormal)
            .frame(height: 1)
            .padding(.horizontal, 20)
            .frame(height: 12)
    }

    private var roomList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(rooms) { room in
                    RoomShareRoomCard(room: room, isSelected: selection.contains(room.id)) {
                        selection.toggle(room.id)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .accessibilityIdentifier("RoomShare.roomList")
    }
}

// MARK: - 방 카드

/// 공유 대상 방 한 줄 — 커버 80 + 이름/설명/장소 수 + 체크박스. Figma `room card`(`639:29093`).
private struct RoomShareRoomCard: View {
    let room: RoomShareRoom
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                RoomShareCover()

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(room.name)
                            .mhTypography(.body1NormalBold)
                            .foregroundStyle(.mhLabelNormal)
                            .lineLimit(1)
                        Text(room.memo)
                            .mhTypography(.label2Medium)
                            .foregroundStyle(.mhLabelAlternative)
                            .lineLimit(1)
                    }
                    Text(room.locationCountText)
                        .mhTypography(.label2Bold)
                        .foregroundStyle(.mhLabelAlternative)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                RoomShareCheckbox(isOn: isSelected)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("RoomShare.room.\(room.id)")
        .accessibilityLabel("\(room.name), \(room.locationCountText)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// 방 커버 80×80. Figma 는 `Pink/95` 배경 위에 캐릭터 일러스트를 얹는데 레포에 그 에셋이 없어
/// (`RoomDetailAvatar` 와 같은 관례로) 배경 + 플레이스홀더 아이콘으로 그린다.
private struct RoomShareCover: View {
    /// Figma `Atomic/Pink/95` (#FEECFB). 시맨틱 토큰이 없는 아토믹 색이라 값을 직접 쓴다
    /// (`Color.mhAccentBackgroundPink` 는 #F553DA 로 훨씬 진하다).
    private static let cover = Color(red: 0xFE / 255, green: 0xEC / 255, blue: 0xFB / 255)

    var body: some View {
        RoundedRectangle(cornerRadius: 18.286, style: .continuous)   // Figma radius md
            .fill(Self.cover)
            .frame(width: 80, height: 80)
            .overlay {
                Image(.personFill)
                    .resizable()
                    .frame(width: 38, height: 38)
                    .foregroundStyle(.mhLineNormalNeutral)
            }
    }
}

/// 사각 체크박스 18pt. Figma `Checkbox/Resource/Control`(`913:240056`).
/// DesignSystem 에 아직 없어 이 화면 로컬로 둔다 — 공통화는 체크박스 컴포넌트가 생기는 PR에서.
private struct RoomShareCheckbox: View {
    let isOn: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(isOn ? Color.mhPrimaryNormal : .clear)
            .overlay {
                if isOn {
                    Image(.checkThick)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(.mhStaticWhite)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(.mhLineNormalNormal, lineWidth: 1.5)
                }
            }
            .frame(width: 18, height: 18)
            .padding(4)
    }
}

/// 공유할 장소의 썸네일 46pt. 사진 에셋이 없어 카드 썸네일과 같은 플레이스홀더로 그린다.
private struct RoomShareLocationThumbnail: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 7.83, style: .continuous)
            .fill(.mhBackgroundNormalNormal)
            .overlay {
                RoundedRectangle(cornerRadius: 7.83, style: .continuous).fill(.mhFillAlternative)
            }
            .overlay {
                Image(.image)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.mhLineNormalNeutral)
            }
            .frame(width: 46, height: 46)
    }
}

#Preview("공유 시트") {
    RoomShareSheet(
        location: RoomDetailLocation.samples[0],
        rooms: RoomShareRoom.samples,
        onClose: {},
        onSubmit: { _ in }
    )
    .frame(height: RoomShareSheet.detentHeight)
}
