import DesignSystem
import Domain
import Foundation
import MVI
import SwiftUI

/// 장소를 다른 방에 공유하는 바텀시트. Figma `004-2-2_다른 방에 공유 클릭`(`1672:73592`).
///
/// 시안이 딤(`Material/Dimmer`)을 동반한 모달이라 `MHBottomSheet`(딤 없는 비모달 3-detent)이 아니라
/// SwiftUI 네이티브 `.sheet` + `presentationDetents` 위에 얹는다. 띄우는 쪽은 `ProfileTabView`.
///
/// Coordinator 대신 `makeStore` 클로저를 받는다(`.claude/docs/mvi-coordinator-di.md` 5절) —
/// 방 목록 로드·저장·저장 중 잠금이 Store 안에 있고, 시트 자신은 누가 만들었는지 몰라도 된다.
struct RoomShareSheet: View {
    /// `presentationDetents(.height(_:))` 에 넘길 값.
    ///
    /// 시안 시트 높이 500 은 홈 인디케이터(34)까지 포함한 값인데, iOS 의 `.height` 는 하단 안전영역
    /// **위쪽** 높이라 그만큼 뺀다(시뮬레이터 실측: 500 을 주면 화면상 534 가 나온다).
    /// 홈 인디케이터가 없는 기기에서는 시트가 34pt 짧아지지만 리스트가 그만큼 줄 뿐이라 무해하다.
    static let detentHeight: CGFloat = 500 - 34

    let location: RoomDetailLocation
    let makeStore: @MainActor () -> RoomShareStore
    let onClose: () -> Void

    @State private var store: RoomShareStore?

    var body: some View {
        VStack(spacing: 0) {
            grabber
            locationHeader
            newRoomRow
            dividerRow
            content
        }
        .background(.mhBackgroundElevatedNormal)
        .accessibilityIdentifier("RoomShare.sheet")
    }

    /// 방 목록·공유 버튼은 Store 가 생긴 뒤에 그린다. 그래버·헤더(닫기)는 바깥에 둬서
    /// 생성 전에도 시트를 닫을 수 있다.
    @ViewBuilder private var content: some View {
        if let store {
            RoomShareContentView(state: store.state, send: store.send)
        } else {
            // Store 는 여기서 1회 생성한다 — `makeStore` 가 @MainActor 라 View.init 에서는 못 부른다.
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task { store = makeStore() }
        }
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
}

// MARK: - 목록 + 공유 버튼

/// Store 가 생긴 뒤의 본문. 진입 로드는 여기서 1회 보낸다(Store 생성과 분리).
private struct RoomShareContentView: View {
    let state: RoomShareState
    let send: (RoomShareAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            roomList
            // safeArea: false — 시트가 이미 홈 인디케이터 높이를 확보한다. 켜 두면 34pt 가 이중으로 잡혀
            // 시트가 시안(500)보다 그만큼 커진다.
            MHActionArea(main: .init("공유하기") { send(.tapSubmit) }, safeArea: false)
                .disabled(!state.canSubmit)
                .accessibilityIdentifier("RoomShare.submitButton")
        }
        .task { send(.load) }
    }

    @ViewBuilder private var roomList: some View {
        if state.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("RoomShare.roomList.loading")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(state.rooms) { room in
                        RoomShareRoomCard(
                            room: room,
                            isSelected: state.checkedRoomIDs.contains(room.id),
                            onToggle: { send(.toggleRoom(room.id)) }
                        )
                        // 이미 저장된 방은 체크된 채 비활성(기획 011-1 ④) —
                        // `MHCheckbox` 가 `isEnabled` 를 읽어 흐려지고 행 탭도 함께 죽는다.
                        .disabled(state.alreadySavedRoomIDs.contains(room.id))
                    }
                }
                .padding(.horizontal, 20)
            }
            .accessibilityIdentifier("RoomShare.roomList")
        }
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

                // 행 전체가 버튼이라 체크박스는 표시 전용(action 없음) — 탭은 행이 받는다.
                MHCheckbox(state: isSelected ? .checked : .unchecked)
                    .padding(4)   // Figma Checkbox p-4
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
    var body: some View {
        RoundedRectangle(cornerRadius: 18.286, style: .continuous)   // Figma radius md
            .fill(.mhPink95)                                          // Figma atomic `Pink/95`
            .frame(width: 80, height: 80)
            .overlay {
                Image(.personFill)
                    .resizable()
                    .frame(width: 38, height: 38)
                    .foregroundStyle(.mhLineNormalNeutral)
            }
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

/// 프리뷰용 공유 대상 — 첫 방은 "이미 저장됨"이라 체크된 채 비활성으로 뜬다.
private struct PreviewShareTargets: FetchShareTargetsUseCase {
    func execute(pinID: PinID) async throws -> [ShareTarget] {
        (0..<5).map { index in
            ShareTarget(
                room: Room(
                    id: "room-\(index)", type: .shared, name: "내 방", description: "내가 꾹 저장한 장소",
                    color: .orange, ownerId: "u1", createdAt: Date(timeIntervalSince1970: 0),
                    pinCount: 0, memberCount: 1, users: []
                ),
                alreadySaved: index == 0
            )
        }
    }
}

private struct PreviewSavePin: SavePinToRoomsUseCase {
    func execute(pinID: PinID, roomIDs: Set<String>) async throws {}
}

#Preview("공유 시트") {
    RoomShareSheet(
        location: RoomDetailLocation.samples[0],
        makeStore: {
            RoomShareStore(
                RoomShareState(pinID: PinID("pin-0")),
                reduce: roomShareReducer(fetchTargets: PreviewShareTargets(), savePin: PreviewSavePin())
            )
        },
        onClose: {}
    )
    .frame(height: RoomShareSheet.detentHeight)
}
