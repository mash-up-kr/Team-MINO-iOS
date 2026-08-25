import DesignSystem
import Domain
import SwiftUI

/// 방 선택 바텀 시트 콘텐츠. Figma `002-4-1 방변경`(node 2809-139474) 실측에 맞춘다.
///
/// "방 리스트" 타이틀 + 3열 방 그리드(맨 앞 "방 만들기" 셀, 이어서 방 커버·이름). 시트 컨테이너
/// (높이 400 고정·딤·그래버)는 이 뷰를 표시하는 화면의 `.sheet` 가 맡는다 — 여기서는 콘텐츠만 그린다.
struct RoomListView: View {
    let rooms: [Room]
    /// 현재 선택된 방(핑크 하이라이트 대상).
    let currentRoomID: RoomID?
    let onSelectRoom: (RoomID) -> Void
    let onCreateRoom: () -> Void

    // Figma 실측(node 2809-139474)
    private let coverSize: CGFloat = 70
    private var coverRadius: CGFloat { coverSize * 14 / 80 }   // MHRoomThumbnail 과 동일 radius (70 → 12.25)
    private let columnGap: CGFloat = 45     // 셀 간 가로 간격 (row 300 안 70×3 + 45×2)
    private let rowGap: CGFloat = 28        // 행 간 세로 간격 (98 + 28)
    private let sideInset: CGFloat = 37.5   // 그리드 좌우 여백 (padding 20 + 행 중앙정렬 17.5)
    private let labelGap: CGFloat = 12      // 커버 ↔ 이름

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: columnGap), count: 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            grabber

            // 타이틀 영역 60pt (Frame 303): 타이틀 leading 20 · top 14
            Text("방 리스트")
                .mhTypography(.title3Bold)
                .foregroundStyle(.mhLabelStrong)
                .padding(.leading, 20)
                .padding(.top, 14)
                .frame(height: 60, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)

            ScrollView {
                LazyVGrid(columns: columns, spacing: rowGap) {
                    createCell
                    ForEach(rooms, id: \.id) { room in
                        roomCell(room)
                    }
                }
                .padding(.horizontal, sideInset)
                .padding(.top, 16)     // 타이틀 영역 ↔ 그리드 (md = 16)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.mhBackgroundElevatedNormal)
        .accessibilityIdentifier("Home.roomList")
    }

    /// 시트 상단 그래버(controller). Figma node 2809-139472: 38×4 pill(Fill/Normal), 위아래 13 패딩(총 30) · 가로 중앙.
    /// 시스템 그래버(presentationDragIndicator)는 스펙이 달라 끄고 이걸 직접 그린다.
    private var grabber: some View {
        Capsule()
            .fill(Color.mhFillNormal)
            .frame(width: 38, height: 4)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
    }

    // MARK: - 셀

    /// 맨 앞 "방 만들기" 셀 — 커버 자리에 라인 테두리 + 24pt 플러스 아이콘.
    private var createCell: some View {
        Button(action: onCreateRoom) {
            cell(label: "방 만들기") {
                RoundedRectangle(cornerRadius: coverRadius)
                    .strokeBorder(Color.mhLineNormalNeutral, lineWidth: 1)
                    .frame(width: coverSize, height: coverSize)
                    .overlay {
                        Image(MHIcon.plus)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.mhLabelAlternative)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("Home.roomList.create")
    }

    /// 현재 방은 썸네일에 체크(딤 + ✓)로 표시하고 탭을 막는다 — 이미 보고 있는 방이라 재선택할 게 없다.
    /// 시안(node 2809-139491)에는 이전의 핑크 테두리 대신 이 체크 상태만 있다.
    ///
    /// 선택된 셀은 `.disabled` 를 건 버튼이 아니라 **버튼이 아닌 정적 셀**로 그린다 —
    /// `.disabled` 는 SwiftUI 가 라벨(방 이름 텍스트)까지 흐리게 만들어, 이름이 검정으로 남는
    /// 시안과 달라진다(시뮬레이터에서 확인).
    @ViewBuilder
    private func roomCell(_ room: Room) -> some View {
        let isSelected = room.id == currentRoomID
        if isSelected {
            cell(label: room.homeDisplayName) {   // 공동방 "…방" / 개인방 "내 장소"
                cover(for: room, isSelected: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isSelected)
            .accessibilityIdentifier("Home.roomList.room.\(room.id.value)")
        } else {
            Button { onSelectRoom(room.id) } label: {
                cell(label: room.homeDisplayName) {
                    cover(for: room, isSelected: false)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("Home.roomList.room.\(room.id.value)")
        }
    }

    /// 커버(70×70) + 이름 라벨(12 간격) 공통 셀 레이아웃.
    private func cell(label: String, @ViewBuilder cover: () -> some View) -> some View {
        VStack(spacing: labelGap) {
            cover()
            Text(label)
                .mhTypography(.caption1Medium)
                .foregroundStyle(.mhLabelNeutral)
                .lineLimit(1)
                .truncationMode(.tail)   // 긴 방 이름은 뒷글자를 …로 자름 (바텀시트 디자인 확정 전 임시 처리)
        }
        .frame(maxWidth: .infinity)
    }

    /// 방 커버 — 방 색이 팔레트에 있으면 그 색 썸네일, 없으면 my-room 썸네일.
    @ViewBuilder
    private func cover(for room: Room, isSelected: Bool) -> some View {
        if let color = MHRoomThumbnailColor(roomColorHex: room.color) {
            MHRoomThumbnail(color: color, size: coverSize, isSelected: isSelected)
        } else {
            MHRoomThumbnail.myRoom(size: coverSize, isSelected: isSelected)
        }
    }
}
