import DesignSystem
import SwiftUI

/// 저장할 방을 고르는 바텀시트 콘텐츠. Figma `013-1-3 게시물 저장`(node 2862:177988).
///
/// 그래버 + "게시물 저장" 헤더 + 방 목록(체크박스) + `저장하기` 액션까지만 그린다.
/// **높이·배경·딤은 그리지 않는다** — 홈은 시스템 `.sheet`(딤 포함), 익스텐션은 호스트 화면 위에
/// 직접 얹는 오버레이라 컨테이너가 서로 다르기 때문이다. 띄우는 쪽이 ``SavePostSheetMetrics`` 로
/// 높이를 정하고 배경을 깐다.
///
/// 상태를 들지 않는다 — 선택은 `checkedRoomIDs` 로 받고 탭은 `onToggleRoom` 으로 돌려준다.
public struct SavePostSheet: View {
    private let rooms: [SavePostRoom]
    private let checkedRoomIDs: Set<String>
    private let disabledRoomIDs: Set<String>
    private let canSubmit: Bool
    private let safeAreaBottom: CGFloat
    private let identifierPrefix: String
    private let onToggleRoom: (String) -> Void
    private let onSave: () -> Void

    /// 액션 영역 실측 높이 — 목록 하단 여백을 이만큼 줘야 마지막 카드가 버튼에 가리지 않는다.
    @State private var actionAreaHeight: CGFloat = 0

    /// - Parameters:
    ///   - checkedRoomIDs: 체크로 보이는 방 — 이미 저장된 방도 포함해서 넘긴다(Figma 013-1-2).
    ///   - disabledRoomIDs: 이미 이 게시물이 들어 있어 끌 수 없는 방(중복 저장 방지, Figma 002-1).
    ///   - safeAreaBottom: 액션 영역 아래로 확보할 홈 인디케이터 높이. 시스템 시트처럼 SwiftUI 가
    ///     이미 하단 인셋을 넣어 주는 컨테이너에서는 0 을 준다(이중으로 잡히면 시안보다 커진다).
    ///   - identifierPrefix: 접근성 식별자 접두어(`\(prefix).sheet` 식). 같은 시트를 여러 진입점이
    ///     쓰므로 QA 시나리오가 화면을 구분할 수 있게 호출부가 정한다.
    public init(
        rooms: [SavePostRoom],
        checkedRoomIDs: Set<String>,
        disabledRoomIDs: Set<String> = [],
        canSubmit: Bool,
        safeAreaBottom: CGFloat = 0,
        identifierPrefix: String,
        onToggleRoom: @escaping (String) -> Void,
        onSave: @escaping () -> Void
    ) {
        self.rooms = rooms
        self.checkedRoomIDs = checkedRoomIDs
        self.disabledRoomIDs = disabledRoomIDs
        self.canSubmit = canSubmit
        self.safeAreaBottom = safeAreaBottom
        self.identifierPrefix = identifierPrefix
        self.onToggleRoom = onToggleRoom
        self.onSave = onSave
    }

    public var body: some View {
        VStack(spacing: 0) {
            grabber
            header
            roomList
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("\(identifierPrefix).sheet")
    }

    /// 시안 스펙 그래버. 내려서 닫는 동작은 시스템 시트(홈)·바깥탭(익스텐션)이 맡으므로 표시 전용이다.
    private var grabber: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.mhFillNormal)
            .frame(width: 38, height: 4)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .accessibilityHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("게시물 저장")
                .mhTypography(.heading2Bold)
                .foregroundStyle(Color.mhLabelNormal)
            Text("장소를 저장할 방을 선택해주세요.")
                .mhTypography(.label1NormalRegular)
                .foregroundStyle(Color.mhLabelNeutral)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("\(identifierPrefix).header")
    }

    private var roomList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(rooms) { room in
                    MHRoomCard(
                        title: room.name,
                        memo: room.memo,
                        placeCount: room.placeCount,
                        thumbnail: room.thumbnail,
                        selection: Binding(
                            get: { checkedRoomIDs.contains(room.id) },
                            set: { _ in onToggleRoom(room.id) }
                        )
                    )
                    .padding(.horizontal, 20)
                    // 체크박스는 18pt 라 겨냥이 어렵다 — 줄 전체를 탭 영역으로 넓힌다.
                    .contentShape(Rectangle())
                    .onTapGesture { onToggleRoom(room.id) }
                    // 이미 저장된 방은 체크된 채 비활성(MHCheckbox 가 isEnabled 를 읽어 흐려진다).
                    // 줄 탭보다 **바깥**에 걸어야 넓힌 탭 영역까지 함께 죽는다.
                    .disabled(disabledRoomIDs.contains(room.id))
                    .accessibilityIdentifier("\(identifierPrefix).room.\(room.id)")
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: .infinity)
        // 액션 영역을 목록 **위에 얹는다** — 시안(013-1-3)에서 목록 프레임은 잘리지 않고 카드가 버튼
        // 영역 아래로 흘러 들어가며, 액션 영역 상단의 20pt 페이드가 그 경계를 흐린다.
        // `contentMargins` 로 같은 높이만큼 스크롤 콘텐츠 여백을 줘, 끝까지 내리면 마지막 카드가
        // 버튼에 가리지 않고 온전히 보인다.
        // (`safeAreaInset` 은 인셋까지 한 번에 처리해 주지만 스크롤 콘텐츠를 그 경계에서 잘라 버려
        //  카드가 페이드 없이 하드 컷 된다 — 시뮬레이터 실측 확인)
        .contentMargins(.bottom, actionAreaHeight, for: .scrollContent)
        .overlay(alignment: .bottom) { actionArea }
    }

    /// 하단 CTA. Figma `Action Area/Action Area`(node 2862:178004).
    ///
    /// `sticky` 가 시안의 `Gradient/Solid` 배경이다 — 상단 20pt 알파 페이드 + 그 아래 불투명
    /// `Background/Elevated/Normal` 채움으로, 뒤로 지나가는 카드가 버튼 앞에서 서서히 사라진다.
    private var actionArea: some View {
        VStack(spacing: 0) {
            // safeArea: false — 홈 인디케이터 여백은 safeAreaBottom 으로 호출부가 정한다.
            MHActionArea(
                main: .init("저장하기", isEnabled: canSubmit, action: onSave),
                sticky: true,
                safeArea: false
            )
            // sticky 배경은 **컨테이너 안전영역**까지만 내려간다. 익스텐션처럼 그 인셋을 직접 들고 있는
            // (ignoresSafeArea) 화면에서는 여기까지 닿지 않아, 그 띠를 같은 색으로 직접 메운다.
            if safeAreaBottom > 0 {
                Color.mhBackgroundElevatedNormal
                    .frame(height: safeAreaBottom)
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { actionAreaHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { _, height in actionAreaHeight = height }
            }
        }
    }
}

#Preview("방 5개 — 644") {
    let rooms = [
        SavePostRoom(id: "1", name: "내 장소", placeCount: 0),
        SavePostRoom(id: "2", name: "민호야 잘하자", placeCount: 9, thumbnail: .color(.violet)),
        SavePostRoom(id: "3", name: "매쉬업 화이팅", memo: "팀원 모두가 좋아할 만한 술집 모음",
                     placeCount: 2, thumbnail: .color(.orange)),
        SavePostRoom(id: "4", name: "언젠가 가야지", memo: "저장만 하고 안 간 곳들",
                     placeCount: 3, thumbnail: .color(.blue)),
        SavePostRoom(id: "5", name: "성수 카페 투어", memo: "주말에 가볼 곳",
                     placeCount: 8, thumbnail: .color(.green)),
    ]
    return ZStack(alignment: .bottom) {
        Color.mhMaterialDimmer.ignoresSafeArea()
        SavePostSheet(
            rooms: rooms,
            checkedRoomIDs: ["2", "3"],
            disabledRoomIDs: ["2"],
            canSubmit: true,
            safeAreaBottom: SavePostSheetMetrics.designSafeAreaBottom,
            identifierPrefix: "SavePost",
            onToggleRoom: { _ in },
            onSave: {}
        )
        .frame(height: SavePostSheetMetrics.height(roomCount: rooms.count, safeAreaBottom: 34))
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .fill(Color.mhBackgroundElevatedNormal)
        }
    }
}
