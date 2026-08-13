import DesignSystem
import Domain
import SwiftUI

/// 홈 셸 콘텐츠. 방 뱃지 헤더 + 타이틀 + 필터바 + (카드 덱 자리 | 빈상태 A).
struct HomeContentView: View {
    let store: HomeStore

    // 플로팅 "더 보기" 버튼은 여기(NavigationStack 안)가 아니라 HomeTabView 의 스택에 둔다 —
    // NavigationStack 이 상위 safeAreaInset(탭바)을 콘텐츠에 전파하지 않아, 안에 두면 탭바에 가린다.
    var body: some View {
        ZStack(alignment: .topTrailing) {
            mainContent
            mascotCharacter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.mhBackgroundNormalAlternative)
        .task { store.send(.load) }
    }

    @ViewBuilder
    private var mainContent: some View {
        if store.state.isEmpty {
            emptyStateContent
        } else {
            dataContent
        }
    }

    // MARK: - 데이터 있을 때 (로딩 중에도 헤더·필터바 레이아웃 유지)

    private var dataContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 32)
                .padding(.horizontal, 20)

            filterBar
                .padding(.top, 32)
                .padding(.horizontal, 20)

            if store.state.isLoading {
                Spacer()
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("Home.state.loading")
                Spacer()
            } else if !store.state.pins.isEmpty {
                CardDeckView(
                    pins: store.state.pins,
                    currentIndex: store.state.currentCardIndex,
                    onSwipeForward: { store.send(.swipeForward) },
                    onSwipeBackward: { store.send(.swipeBackward) },
                    onTapCard: { store.send(.tapCard($0)) },
                    onTapMore: { store.send(.tapMore($0)) }
                )
                .padding(.top, 112)   // 앞 카드 고정 위치. 풀 덱일 때 뒤 카드 최상단이 필터 32pt 아래(112−80)에 오도록
                .accessibilityIdentifier("Home.cardDeck")
                Spacer()
            } else {
                Spacer()
            }
        }
    }

    // MARK: - 헤더 (방 뱃지 or 로고 + 타이틀)

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let room = store.state.currentRoom {
                MHContentBadge(room.name)
                    .accessibilityIdentifier("Home.roomBadge")
            } else {
                Text("GGUK")
                    .mhTypography(.heading1Bold)
                    .foregroundStyle(.mhPrimaryNormal)
                    .accessibilityIdentifier("Home.emptyState.logo")
            }

            Text("꾹 눌러둔 장소,\n다시 꺼내볼까요?")
                .mhTypography(.heading1Bold)
                .foregroundStyle(.mhLabelNormal)
                .lineSpacing(8)
                .accessibilityIdentifier("Home.title")
        }
    }

    // MARK: - 필터바

    private var filterBar: some View {
        MHCategory(
            ["꾹 Pick", "최신순", "가까운순"],
            selection: Binding(
                get: { store.state.selectedFilter },
                set: { store.send(.selectFilter($0)) }
            )
        )
        .accessibilityIdentifier("Home.filterBar")
    }

    // MARK: - 빈상태 A (방 없음)

    private var emptyStateContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 32)
                .padding(.horizontal, 20)

            filterBar
                .padding(.top, 32)
                .padding(.horizontal, 20)

            // 일러스트 + 카피 + CTA (헤더로부터 58pt)
            VStack(spacing: 20) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.mhBackgroundNormalAlternative)
                    .frame(width: 249, height: 249)
                    .overlay {
                        Text("이미지 교체 예정")
                            .mhTypography(.body2NormalMedium)
                            .foregroundStyle(.mhLabelAlternative)
                    }
                    .accessibilityIdentifier("Home.emptyState.illustration")

                VStack(spacing: 0) {
                    Text("\"저번에 말한 거기가 어디였지?\"")
                        .mhTypography(.label1NormalRegular)
                        .foregroundStyle(.mhPrimaryNormal)

                    Text("더 이상 묻지 말고, 친구와 함께 장소를 저장해 보세요.")
                        .mhTypography(.label1NormalRegular)
                        .foregroundStyle(.mhPrimaryNormal)
                }
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("Home.emptyState.copy")

                MHButton(
                    "공동방 만들기",
                    variant: .solid,
                    color: .primary,
                    size: .medium,
                    leadingIcon: .plus
                ) {
                    store.send(.tapCreateRoom)
                }
                .accessibilityIdentifier("Home.emptyState.createRoomButton")
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 58)
        }
    }

    // MARK: - 마스코트 캐릭터

    private var mascotCharacter: some View {
        Image(dsImage: "homeMascot")
            .resizable()
            .scaledToFit()
            .frame(width: 131)
            .rotationEffect(.degrees(-27.52))
            .padding(.top, 8)
            .padding(.trailing, -55)
            .accessibilityIdentifier("Home.mascot")
    }
}

// MARK: - Preview

#Preview("데이터 있을 때") {
    HomeContentView(
        store: HomeStore(
            HomeState(rooms: [
                Room(
                    id: "1", type: .shared, name: "맛집 탐방", description: nil,
                    color: "#FF6B6B", ownerId: "o", inviteCode: "A",
                    createdAt: .now, pinCount: 3, memberCount: 2, users: []
                ),
            ]),
            reduce: homeReducer(fetchRooms: PreviewFetchRooms())
        )
    )
}

#Preview("빈상태 A") {
    HomeContentView(
        store: HomeStore(
            HomeState(),
            reduce: homeReducer(fetchRooms: PreviewFetchRooms())
        )
    )
}

/// 프리뷰 전용 UseCase. load 액션을 보내도 빈 배열을 반환한다.
private struct PreviewFetchRooms: FetchRoomsUseCase {
    func execute() async throws -> [Room] { [] }
}
