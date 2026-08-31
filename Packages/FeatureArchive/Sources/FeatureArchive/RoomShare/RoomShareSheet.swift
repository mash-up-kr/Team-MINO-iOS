import DesignSystem
import Domain
import FlowCoordination
import Foundation
import MVI
import RoomCreationUI
import SwiftUI

/// 장소를 다른 방에 공유하는 바텀시트. Figma `004-2-2_다른 방에 공유 클릭`(`1672:73592`).
///
/// 시안이 딤(`Material/Dimmer`)을 동반한 모달이라 `MHBottomSheet`(딤 없는 비모달 3-detent)이 아니라
/// SwiftUI 네이티브 `.sheet` + `presentationDetents` 위에 얹는다. 띄우는 쪽은 ``ArchiveShellView``.
///
/// **부모** Coordinator 대신 `makeStore` 클로저를 받는다(`.claude/docs/mvi-coordinator-di.md` 5절) —
/// 방 목록 로드·저장·저장 중 잠금이 Store 안에 있고, 시트 자신은 누가 띄웠는지 몰라도 된다.
/// 반면 **자식** flow(``RoomShareCreateRoomCoordinator``)는 시트가 직접 안다 — 커버를 시트 안에
/// 붙여야 시트를 살려 둔 채 덮을 수 있기 때문이다(`MemberHomeView` 가 `editChild` 를 아는 것과 같다).
struct RoomShareSheet: View {
    let location: RoomDetailLocation
    let makeStore: @MainActor () -> RoomShareStore
    /// 공동방 만들기 자식 flow. **시트 안에서** 커버로 띄운다 — 시트를 닫고 띄우면
    /// 고르던 방 선택이 사라지고, 시트 바깥(껍데기)에 붙이면 시트가 위를 덮어 안 보인다.
    /// 항목 자체가 자식 Coordinator 라 닫힐 때 SwiftUI 가 nil 을 되써 표시 상태와 자식이
    /// 어긋나지 않는다(`.claude/docs/mvi-coordinator-di-extensions.md` "다중 sheet" 와 같은 이유).
    @Binding var createRoomChild: RoomShareCreateRoomCoordinator?
    let onClose: () -> Void
    /// 커버에서 방이 **실제로 만들어졌을 때** 1회. 시트 밖(방 리스트)도 낡기 때문에 알려야 한다 —
    /// 시트가 떠 있는 동안 껍데기는 사라지지 않아 `.task` 재조회가 걸리지 않는다(``ArchiveShellView``).
    /// 취소로 돌아온 경우에는 부르지 않는다.
    var onRoomCreated: () -> Void = {}

    @State private var store: RoomShareStore?
    /// 시트 단계. 진입은 peek 이다(기획 011-1 ①).
    @State private var detent: PresentationDetent = .height(RoomShareSheetMetrics.peekDetentHeight)

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
        // 다른 presentation 설정과 달리 **여기** 붙는다(나머지는 띄우는 쪽 ``ArchiveShellView``) —
        // full 높이가 방 개수로 갈리는데(676/708) 그 개수는 시트 안에서 만드는 `RoomShareStore` 만
        // 안다. 껍데기에 두려면 껍데기가 Store 를 소유해야 하고, 그러면 "누가 띄웠는지 몰라도 되게"
        // 하려고 `makeStore` 클로저를 받은 구조가 무너진다.
        .presentationDetents(
            [.height(RoomShareSheetMetrics.peekDetentHeight), .height(fullDetentHeight)],
            selection: $detent
        )
        .onChange(of: fullDetentHeight) { old, new in
            // 방을 만들고 돌아와 4→5 로 넘어가면 full 높이가 바뀐다. `PresentationDetent` 는 값으로
            // 같고 다름을 가려 옛 높이를 든 selection 은 집합 밖이 되므로 새 값으로 옮겨 준다.
            if detent == .height(old) { detent = .height(new) }
        }
        .fullScreenCover(item: $createRoomChild) { child in
            // 저장 탭 헤더 "+" 와 같은 화면 — 건너뛰기 없음(showsSkip: false).
            RoomFormView(makeStore: child.makeRoomFormStore, showsSkip: false)
                // 결과는 reduce 로 한 줄 위임한다(목록을 다시 받을지 말지는 reduce 가 정한다).
                // [weak store]: 자식 → finish 클로저 → 시트 → 부모 → 자식 순환을 끊는다.
                .flowRoot(child) { [weak store] result in
                    store?.send(.createRoomFinished(result))
                    // 한 결과에 소비자가 둘이라 여기서 갈라 준다 — reduce 는 effect 를 하나만 낸다.
                    if result == .created { onRoomCreated() }
                }
        }
    }

    /// 로딩 중에는 방 개수를 모른다 — 0 으로 보고 있다가 목록이 오면 한 번 자란다(`SaveLinkView`
    /// 와 같은 처리). 진입 단계가 peek 이라 사용자가 끌어올리기 전에는 이 값이 눈에 띄지 않는다.
    private var fullDetentHeight: CGFloat {
        RoomShareSheetMetrics.fullDetentHeight(roomCount: store?.state.rooms.count ?? 0)
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
            RoomShareLocationThumbnail(photo: location.thumbnail)

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

            MHCircleIconButton(icon: .close, accessibilityLabel: "닫기", action: onClose)
        }
        .padding(.horizontal, 20)
        .frame(height: 60)
    }

    // 새 방 만들기 — Figma `1672:73605`. 눌러 공동방 만들기로 들어간다(기획 011-1 ③).
    private var newRoomRow: some View {
        HStack {
            Button {
                // Store 가 없는 건 시트가 뜬 첫 프레임뿐이다(`content` 의 `.task` 가 바로 만든다) —
                // 사람이 누를 수 있는 시점에는 이미 있다.
                store?.send(.tapCreateRoom)
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

/// 공유할 장소의 썸네일 46pt — 그 장소 사진 중 **첫 장**이다(기획 011-1 ②).
///
/// 사진이 없거나 로딩·실패 중에는 자리표로 떨어진다 — 셋을 같은 자리표로 받는 건
/// ``PlaceDetailPhotoCarousel`` 과 같은 이유로, 자리가 비면 옆 텍스트가 밀리기 때문이다.
private struct RoomShareLocationThumbnail: View {
    let photo: URL?

    private static let side: CGFloat = 46
    private static let cornerRadius: CGFloat = 7.83

    var body: some View {
        Group {
            if let photo {
                AsyncImage(url: photo) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: Self.side, height: Self.side)
        .clipShape(shape)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.mhFillAlternative)
            .overlay {
                Image(.image)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.mhLineNormalNeutral)
            }
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
        createRoomChild: .constant(nil),
        onClose: {}
    )
    .frame(height: RoomShareSheetMetrics.peekDetentHeight)
}
