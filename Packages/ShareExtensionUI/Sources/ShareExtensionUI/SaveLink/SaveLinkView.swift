import Core
import DesignSystem
import SwiftUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — Store 는 .task 에서 1회 lazy 생성

/// 공유받은 링크를 방에 저장하는 바텀시트. Figma `013-1 외부 공유 시 바텀시트`(node 2661:164102 외).
///
/// Coordinator 대신 `makeStore` 클로저를 받는다: 익스텐션에는 Coordinator 가 없고
/// `ShareViewController` 가 Store 를 만들어 navigation 을 소비한다.
public struct SaveLinkView: View {
    private let makeStore: @MainActor () -> SaveLinkStore
    @State private var store: SaveLinkStore?

    public init(makeStore: @escaping @MainActor () -> SaveLinkStore) {
        self.makeStore = makeStore
    }

    public var body: some View {
        // 시트 높이가 시안의 고정 pt 값이라 하단 safe-area 를 알아야 한다(높이 상수 주석 참조).
        // `ignoresSafeArea` 는 GeometryReader 가 아니라 그 **안쪽**에 건다 — 밖에 걸면
        // proxy.safeAreaInsets 가 0 으로 보고돼 시트가 홈 인디케이터 높이만큼 짧아진다.
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                // 시트 밖은 비워 둔다 — 시안의 회색은 "기존 뷰 위에 시트가 올라온다"는 표시일 뿐
                // 우리가 그릴 딤이 아니다(호스트 화면이 그대로 비친다). 탭으로 닫는 영역만 남긴다.
                //
                // `Color.clear` 로 두면 탭이 오지 않아(시뮬레이터 확인) 눈에 띄지 않는 최소
                // 불투명도를 준다 — 색이 아니라 히트 테스트가 목적이다.
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { store?.send(.tapClose) }

                if let store {
                    // 저장이 끝나면 시트는 사라지고 딤 위에 스낵바만 남는다(Figma `013-2`).
                    if store.state.isSaved {
                        savedFeedback
                    } else {
                        SaveLinkContent(
                            rooms: store.state.rooms,
                            isChecked: { store.state.isChecked($0) },
                            savedRoomIDs: store.state.savedRoomIDs,
                            canSubmit: store.state.canSubmit,
                            safeAreaBottom: proxy.safeAreaInsets.bottom,
                            onToggleRoom: { store.send(.toggleRoom($0)) },
                            onSave: { store.send(.tapSave) }
                        )
                        .transition(.move(edge: .bottom))
                    }
                } else {
                    ProgressView()
                        .task { store = makeStore() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .animation(.spring(duration: 0.3), value: store?.state.isSaved)
        }
    }

    /// Figma `013-2 방 선택 완료 후 저장 피드백` — 화면 바닥에서 40pt 띄운 스낵바.
    private var savedFeedback: some View {
        MHSnackbar(title: "저장이 완료됐습니다.", icon: .check)
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .accessibilityIdentifier("SaveLink.completionSnackbar")
    }
}

/// 값과 콜백만 받는 마크업. Store 를 모른다.
struct SaveLinkContent: View {
    let rooms: [SharedRoom]
    let isChecked: (String) -> Bool
    let savedRoomIDs: Set<String>
    let canSubmit: Bool
    let safeAreaBottom: CGFloat
    let onToggleRoom: (String) -> Void
    let onSave: () -> Void

    // MARK: 시안 고정 높이 (Figma 스펙 시트 node 2792:175979 — 전부 action area 포함)
    //
    // 높이는 **방 개수로 미리 정해진다** — 콘텐츠를 재보지 않는다.
    //   peek(방 3개 이하 포함) 436 · full_4개 612 · full_4개 이상 644
    // 목록 영역은 남는 만큼 차지한다. 예: 644 − 헤더 94 − 액션 68 − safe 34 = 448
    // = 카드 4장(104×4) + 5번째가 잘려 보이는 32(스크롤 어포던스).

    /// 시안 기기의 홈 인디케이터 높이. 아래 값들이 이걸 포함하므로 실제 기기 값으로 갈아끼운다.
    private static let designSafeAreaBottom: CGFloat = 34
    /// 시안의 peek 값. 카드 2장 + 잘린 3번째이고, 방이 3개 이하일 때의 높이다(사용자 확정).
    private static let smallListDesignHeight: CGFloat = 436
    private static let fourRoomsDesignHeight: CGFloat = 612
    private static let manyRoomsDesignHeight: CGFloat = 644

    var body: some View {
        VStack(spacing: 0) {
            grabber
            header
            roomList
            // safeArea: false — 시트가 자기 바닥을 홈 인디케이터까지 늘려 이미 여백을 확보한다.
            MHActionArea(main: .init("저장하기", isEnabled: canSubmit, action: onSave), safeArea: false)
                .padding(.bottom, safeAreaBottom)
        }
        .frame(height: sheetHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
                .fill(Color.mhBackgroundElevatedNormal)
        }
        .accessibilityIdentifier("SaveLink.sheet")
    }

    // MARK: - 높이

    /// 열릴 때 방 개수로 정해지고 **그대로 고정**된다 — 도중에 단계가 바뀌지 않는다.
    private var sheetHeight: CGFloat {
        let design = switch rooms.count {
        case 5...: Self.manyRoomsDesignHeight
        case 4: Self.fourRoomsDesignHeight
        default: Self.smallListDesignHeight
        }
        return design - Self.designSafeAreaBottom + safeAreaBottom
    }

    // MARK: - 조각

    private var grabber: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.mhFillNormal)
            .frame(width: 38, height: 4)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .contentShape(Rectangle())
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
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("SaveLink.header")
    }

    private var roomList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(rooms) { room in
                    let isSaved = savedRoomIDs.contains(room.id)
                    MHRoomCard(
                        title: room.name,
                        memo: room.memo,
                        placeCount: room.placeCount,
                        selection: Binding(
                            get: { isChecked(room.id) },
                            set: { _ in onToggleRoom(room.id) }
                        )
                    )
                    .padding(.horizontal, 20)
                    // 체크박스는 18pt 라 손가락으로 겨냥하기 작다 — 줄 전체를 탭 영역으로 넓힌다.
                    // (체크박스 자체는 MHRoomCard 안의 버튼이 먼저 받는다)
                    .contentShape(Rectangle())
                    .onTapGesture { onToggleRoom(room.id) }
                    // 이미 저장된 방은 체크된 채 비활성 — MHCheckbox 가 isEnabled 를 읽어 43% 로 흐려진다.
                    // 줄 탭보다 **바깥**에 걸어야 넓힌 탭 영역까지 함께 죽는다.
                    .disabled(isSaved)
                    .accessibilityIdentifier("SaveLink.room.\(room.id)")
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: .infinity)
    }
}

#Preview("방 5개 — full 644") {
    ZStack(alignment: .bottom) {
        // 실제로는 호스트 화면이 비친다 — 프리뷰에서 시트 경계를 보려고 깔아둔 배경.
        Color.mhMaterialDimmer.ignoresSafeArea()
        SaveLinkContent(
            rooms: SharedRoom.samples,
            isChecked: { $0 == "2" },
            savedRoomIDs: ["2"],
            canSubmit: false,
            safeAreaBottom: 34,
            onToggleRoom: { _ in },
            onSave: {}
        )
    }
}
