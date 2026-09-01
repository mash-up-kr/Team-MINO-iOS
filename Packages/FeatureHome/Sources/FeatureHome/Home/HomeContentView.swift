import DesignSystem
import Domain
import SavePostUI
import SwiftUI

/// 홈 셸 콘텐츠. 방 뱃지 헤더 + 타이틀 + 필터바 + (카드 덱 자리 | 빈상태 A).
struct HomeContentView: View {
    let store: HomeStore

    var body: some View {
        ZStack(alignment: .topTrailing) {
            guideBackgroundWash  // 홈 가이드 딤 — 콘텐츠 아래(배경색 위)
            mainContent
            roomListDim          // 「홈 방 시트」가 열릴 때 — 마스코트 아래(홈 콘텐츠만 덮는다)
            // 가이드 중에는 방 정체성을 무조건 세운다 — 안내가 뱃지·토끼를 화살표로 가리키므로
            // (「방 뱃지와 토끼를 클릭하면」) 그 둘이 없으면 화살표가 빈자리를 가리킨다.
            if store.state.showsRoomIdentity || store.state.isGuidePresented {
                // 시안에서 바와 캐릭터는 한 그룹(Group 283)이라 함께 넣고, 캐릭터를 바 위에 얹는다.
                mascotBar        // 딤 위 — 밝게 유지. 개인방만 있고 비었을 때만 숨김 (Figma 002-6-1)
                mascotCharacter
            }
            roomChangeTooltip
            savePostDim          // 게시물 저장 시트 딤 — 마스코트 위(002-5 ② 는 화면 전체가 딤)
        }
        .animation(.easeInOut(duration: 0.2), value: store.state.isGuidePresented)   // 루트의 가이드 페이드와 같은 속도
        .animation(.easeInOut(duration: 0.5), value: store.state.changedRoomToastID)
        .animation(.easeInOut(duration: 0.3), value: store.state.isRoomListPresented)
        .animation(.easeInOut(duration: 0.3), value: store.state.savePost != nil)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.mhBackgroundNormalAlternative)
        // 카드 더보기 메뉴를 화면 최상위에 호스팅 — 카드가 발행한 앵커에 스크림+메뉴를 얹는다
        // (콘텐츠 크기 카드가 못 만드는 화면 전체 바깥탭 스크림을 화면 레벨에서 정확한 z-order 로 그린다).
        .mhHomeCardMenuHost()
        .task { store.send(.load) }
        // 가이드도 방·덱 조회와 따로 묻는다(HomeAction.checkGuide 주석) — 안내가 가리키는 덱은
        // 모형이라 조회 결과를 기다릴 이유가 없다. 재진입해도 "1회" 는 markSeen 이 지킨다.
        .task { store.send(.checkGuide) }
        .task(id: store.state.changedRoomToastID) {
            // 방 변경 툴팁은 3초 뒤 사라진다(FR-016). 새 툴팁이 뜨면 방 id 가 바뀌어 타이머가 재시작된다.
            // dismiss 는 이 타이머가 세운 방 id 를 실어 보낸다 — 3초 경계에서 방을 바꾸면
            // 이전 타이머의 dismiss 가 새 방 툴팁을 지우지 않도록 reducer 가 id 로 방어한다.
            guard let roomID = store.state.changedRoomToastID else { return }
            try? await Task.sleep(for: .seconds(3))
            store.send(.dismissRoomToast(roomID))
        }
        .sheet(isPresented: roomListBinding) {
            // 시스템 시트 컨테이너/슬라이드 애니메이션은 그대로 쓰되, 시스템 딤(스크림)만 제거한다.
            // backgroundInteraction 을 켜면 스크림이 사라져 — 그래야 마스코트만 딤 위로 뺄 수 있다 —
            // 딤은 프리젠터 쪽(roomListDim, 마스코트 아래)에서 제자리 페이드로 직접 그린다.
            RoomListView(
                rooms: store.state.rooms,
                currentRoomID: store.state.currentRoom?.id,
                onSelectRoom: { store.send(.selectRoom($0)) },
                onCreateRoom: { store.send(.tapCreateRoom) }
            )
            .presentationDetents([.height(400)])
            .presentationDragIndicator(.hidden)   // 디자인 스펙 그래버를 RoomListView 가 직접 그린다
            .presentationBackgroundInteraction(.enabled(upThrough: .height(400)))   // 시스템 스크림 제거
        }
        .sheet(isPresented: savePostBinding) {
            savePostSheet
        }
    }

    /// 게시물 저장 시트의 딤. Figma `Material/Dimmer`(#171719 52%).
    ///
    /// 시스템 스크림은 색·투명도를 바꾸는 공개 API 가 없고 실측이 검정 12% 라 시안(52%)과 크게 달라,
    /// `presentationBackgroundInteraction` 으로 끄고 여기서 직접 깐다(「홈 방 시트」와 같은 방식).
    /// 탭바 자리는 이 딤이 닿지 않으므로(딤이 탭바보다 아래 레이어) `MainTabView` 가 탭바를
    /// 페이드시켜 뒤의 딤이 비치게 한다 — iOS 26 은 시트를 띄워 그려 시트 아래로 탭바가 드러난다.
    ///
    /// 「홈 방 시트」딤(``roomListDim``)과 **레이어가 다르다**: 저 시트는 마스코트를 딤 위에 남기지만
    /// (뱃지·마스코트가 그 시트의 유일한 진입점이라 밝게 유지한다) 002-5 ② 는 화면 전체를 덮는다.
    /// 뷰 트리에 항상 두고 opacity 만 애니메이션하는 이유는 ``roomListDim`` 과 같다.
    private var savePostDim: some View {
        let presented = store.state.savePost != nil
        return Color.mhMaterialDimmer
            .ignoresSafeArea()
            .opacity(presented ? 1 : 0)
            .contentShape(Rectangle())
            .onTapGesture { store.send(.dismissSavePost) }   // 시스템 스크림의 바깥탭 닫기를 대신한다
            .allowsHitTesting(presented)
            .accessibilityIdentifier("Home.savePost.dim")
    }

    /// 게시물 저장 바텀시트 — [SYS-002] 「게시물 저장 시트」(002-5 ②, Figma `013-1-3` node 2862:177988).
    ///
    /// 마크업은 홈과 공유 익스텐션이 함께 쓰는 ``SavePostSheet`` 가 그리고, 여기서는 시트 컨테이너
    /// (높이·배경·그래버 숨김)만 맡는다. 방 변경용 「홈 방 시트」(``RoomListView``)와는 다른 화면이다 —
    /// 그 시트는 방 변경 전용으로 남는다(FR-018).
    ///
    /// 이미 그 장소가 담긴 방은 체크된 채 비활성으로 뜬다(013-1-3 시안) — 목록은 시트를 열 때
    /// 서버에서 받는다(``SavePostState/alreadySavedRoomIDs``). 조회가 닿기 전 한 프레임 동안은
    /// 아무것도 비활성이 아니지만, 도착하면 reduce 가 선택에서도 빼 준다.
    @ViewBuilder
    private var savePostSheet: some View {
        if let savePost = store.state.savePost {
            SavePostSheet(
                rooms: store.state.rooms.map(SavePostRoom.init(_:)),
                checkedRoomIDs: savePost.checkedRoomIDs,
                disabledRoomIDs: savePost.alreadySavedRoomIDs,
                canSubmit: savePost.canSubmit,
                identifierPrefix: "Home.savePost",
                onToggleRoom: { store.send(.toggleSavePostRoom($0)) },
                onSave: { store.send(.tapSavePost) }
            )
            // safeAreaBottom 0 — 시스템 시트가 하단 인셋을 이미 넣어 준다. detent 높이도 같은 이유로
            // 홈 인디케이터를 뺀 값이다(`.height` 는 안전영역 **위쪽** 높이).
            .presentationDetents([.height(savePostDetentHeight)])
            .presentationDragIndicator(.hidden)   // 그래버는 시안대로 시트 안에서 직접 그린다
            .presentationCornerRadius(20)         // 시안 radius 20 (시스템 기본 10 과 다름)
            .presentationBackground(.mhBackgroundElevatedNormal)
            // 시스템 스크림 제거 — 딤은 시안 색으로 프리젠터가 직접 그린다(savePostDim).
            .presentationBackgroundInteraction(.enabled(upThrough: .height(savePostDetentHeight)))
        }
    }

    /// 홈 진입은 peek/full 단계도 방 개수 분기도 없이 **644 고정**이다(002-5 주석 ②).
    private var savePostDetentHeight: CGFloat {
        SavePostSheetMetrics.homeEntryHeight(safeAreaBottom: 0)
    }

    /// 게시물 저장 시트 표시 바인딩 — 스와이프 dismiss 도 reducer 로 흘려보낸다.
    private var savePostBinding: Binding<Bool> {
        Binding(
            get: { store.state.savePost != nil },
            set: { if !$0 { store.send(.dismissSavePost) } }
        )
    }

    /// 홈 가이드 딤(Figma 「홈 튜토리얼」 `dimd` — white 80% + backdrop blur 6)의 **배경 몫**.
    /// 콘텐츠 아래(배경색 위)에 깔고, 흐려질 요소는 각자 `homeGuideDimmed` 로 물러난다 —
    /// 시안이 방 뱃지·마스코트·맨 앞 카드는 딤 위에 선명하게 남기는 스포트라이트라, 화면을 통째로
    /// 덮는 한 장으로는 그 셋을 다시 꺼낼 수 없다. 안내(화살표·문구·CTA)는 앱 루트의 ``HomeGuideOverlay``.
    ///
    /// 탭바 자리는 이 딤이 닿지 않지만 시안대로 가이드 CTA(Action Area)가 그 위를 통째로 덮는다.
    private var guideBackgroundWash: some View {
        Color.white
            .opacity(store.state.isGuidePresented ? 0.8 : 0)
            .ignoresSafeArea()
            .allowsHitTesting(false)   // 터치 차단은 루트 오버레이가 맡는다
            .accessibilityIdentifier("Home.guide.dim")
    }

    /// 「홈 방 시트」가 열릴 때 홈 콘텐츠 위에 까는 딤(Figma 002-4-1 `rgba(0,0,0,0.7)`).
    /// 마스코트 아래 레이어라 마스코트는 딤에 안 덮인다. 탭하면 시트를 닫는다.
    ///
    /// `다른 방 저장` 은 이제 다른 화면(``savePostSheet``)이라 딤도 따로 쓴다 — 그쪽은 색도
    /// (`Material/Dimmer`) 레이어도(마스코트 위) 다르다.
    ///
    /// 뷰 트리에 **항상** 두고 opacity 만 0↔1 로 애니메이션한다(조건부 삽입/제거 아님). 이유:
    /// `if` + `.transition` 으로 넣다 빼면 사라지는 순간 딤의 z-order 가 흔들려, 페이드아웃 중
    /// 카드덱·필터칩이 딤 위로 잠깐 번쩍 보였다. 항상 존재하면 z-order 가 고정된다.
    private var roomListDim: some View {
        let presented = store.state.isRoomListPresented
        return Color.black.opacity(0.7)
            .ignoresSafeArea()
            .opacity(presented ? 1 : 0)
            .contentShape(Rectangle())
            .onTapGesture { store.send(.dismissRoomList) }
            // 탭 제스처까지 포함해 통째로 게이트 — 가장 바깥에 둬야 닫혀 있을 때 딤이
            // 카드덱 스와이프를 가로채지 않는다(안쪽에 두면 바깥 contentShape·tap 이 터치를 삼킴).
            .allowsHitTesting(presented)
            .accessibilityIdentifier("Home.roomListDim")
    }

    /// 방 선택 시트 표시 바인딩 — 스와이프 dismiss 도 reducer 로 흘려보낸다.
    private var roomListBinding: Binding<Bool> {
        Binding(
            get: { store.state.isRoomListPresented },
            set: { if !$0 { store.send(.dismissRoomList) } }
        )
    }

    // 헤더·필터바는 항상 공통으로 그리고, 본문만 로딩 / 빈 상태 / 카드 덱으로 분기한다.
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, 32)
                .padding(.horizontal, 20)

            filterBar
                .padding(.top, 32)
                .padding(.horizontal, 20)

            contentBody
        }
    }

    /// 정책: 로딩이 끝나고 현재 정렬 기준으로 표시할 카드가 0장이면(방·공동방 유무 무관) 빈 상태를 띄운다.
    ///
    /// 가이드가 떠 있을 때는 실제 덱 대신 **모형 덱**(``HomeGuideMockDeck``)을 그린다 — 맨 앞 카드만
    /// 딤 위에 남는 스포트라이트 구조는 그대로다.
    @ViewBuilder
    private var contentBody: some View {
        if store.state.isGuidePresented {
            guideMockDeck
            Spacer()
        // 기준을 바꿔 덱을 받는 중이면(캐시 없을 때만) 로딩으로 둔다 — 그 사이 빈 상태·소진 화면이
        // 한 프레임 끼어들면 화면이 깜빡인다. 받아 둔 기준으로 되돌아갈 땐 즉시 전환이라 여기 안 걸린다.
        } else if store.state.isLoading || (store.state.isDeckLoading && store.state.pins.isEmpty) {
            Spacer()
            ProgressView()
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("Home.state.loading")
            Spacer()
        } else if store.state.showsEmptyState {
            emptyStateBody
        } else if store.state.hasViewedAllPlaces {
            allViewedBody
        } else {
            CardDeckView(
                pins: store.state.pins,
                currentIndex: store.state.currentCardIndex,
                onSwipeForward: { store.send(.swipeForward) },
                onSwipeBackward: { store.send(.swipeBackward) },
                onTapCard: { store.send(.tapCard($0)) },
                onSaveToOtherRoom: { store.send(.tapSaveToOtherRoom($0)) }
            )
            .padding(.top, 112)   // 앞 카드 고정 위치. 풀 덱일 때 뒤 카드 최상단이 필터 32pt 아래(112−80)에 오도록
            .accessibilityIdentifier("Home.cardDeck")
            Spacer()
        }
    }

    /// 가이드가 가리키는 모형 덱. 실제 덱과 같은 뷰를 같은 자리에 놓아 안내가 끝나면
    /// 그 자리에 진짜 카드가 들어서게 한다(모형을 따로 그리면 치수가 갈라져 닫는 순간 덱이 튄다).
    /// 스와이프·탭 콜백은 비워 둔다 — 가이드 오버레이가 터치를 통째로 막아(``HomeGuideOverlay``)
    /// 여기까지 제스처가 닿지 않고, 모형을 넘겨서 갈 곳도 없다.
    private var guideMockDeck: some View {
        CardDeckView(
            pins: HomeGuideMockDeck.pins,
            currentIndex: 0,
            onSwipeForward: {},
            onSwipeBackward: {},
            onTapCard: { _ in },
            onSaveToOtherRoom: { _ in },
            isGuidePresented: true
        )
        .padding(.top, 112)   // 실제 덱과 같은 자리
        .accessibilityIdentifier("Home.guide.mockDeck")
    }

    // MARK: - 헤더 (방 뱃지 or 로고 + 타이틀)

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let roomBadgeTitle {
                MHContentBadge(roomBadgeTitle, size: .medium)   // 공동방 "…방" / 개인방 "내 장소"
                    .contentShape(Rectangle())
                    .onTapGesture { store.send(.tapRoomBadge) }   // 정책: 뱃지 탭 → 방 선택 바텀 시트
                    .accessibilityIdentifier("Home.roomBadge")
            } else {
                // 개인방만 있고 비었을 때만 방 칩 대신 로고. (Figma 002-6-1)
                // 공동방이 있거나(빈 방이어도) 표시할 장소가 있으면 위 방 칩이 유지된다.
                Text("GGUK")
                    .mhTypography(.heading1Bold)
                    .foregroundStyle(.mhPrimaryNormal)
                    .accessibilityIdentifier("Home.emptyState.logo")
            }

            // 2줄이라 행간까지 붙는 쪽을 쓴다 — Figma 타이틀 블록 60(= 2줄 × 라인박스 30).
            // `.mhTypography` + `.lineSpacing(8)` 이던 시절엔 63 이라 아래 필터·카드덱이 3pt 밀려 있었다.
            Text("꾹 눌러둔 장소,\n다시 꺼내볼까요?")
                .mhTypographyMultiline(.heading1Bold)
                .foregroundStyle(.mhLabelNormal)
                // 가이드의 스포트라이트 대상은 방 뱃지뿐이라 타이틀만 딤 뒤로 물러난다.
                .homeGuideDimmed(store.state.isGuidePresented)
                .accessibilityIdentifier("Home.title")
        }
    }

    /// 방 뱃지 표기. nil 이면 뱃지 자리에 로고(GGUK)가 선다.
    ///
    /// 가이드 중에는 방을 아직 못 읽었어도 표기를 만든다 — 안내가 뱃지를 화살표로 가리키기 때문이다
    /// (「방 뱃지와 토끼를 클릭하면」). 방이 있으면 그 방의 진짜 이름을 쓰고, 없을 때만 모형 표기로
    /// 떨어진다(``HomeGuideMockDeck/roomBadgeTitle``) — 내 방 이름 자리에 가짜 이름을 앉히지 않는다.
    private var roomBadgeTitle: String? {
        if let room = store.state.currentRoom, store.state.showsRoomIdentity || store.state.isGuidePresented {
            return room.homeDisplayName
        }
        return store.state.isGuidePresented ? HomeGuideMockDeck.roomBadgeTitle : nil
    }

    // MARK: - 필터바

    /// 칩 순서는 `PinFilter.allCases` 순서와 1:1 이다 — 표기(한글 라벨)만 Feature 가 매핑한다.
    private var filterBar: some View {
        // 시안 `Category/Category` 인스턴스는 335×40 = 칩 높이 40 → size 는 xLarge.
        // 기본값(medium=32)이던 시절엔 필터바가 8pt 낮아 아래 카드덱이 그만큼 올라와 있었다.
        MHCategory(
            PinFilter.allCases.map(\.chipTitle),
            selection: Binding(
                get: { PinFilter.allCases.firstIndex(of: store.state.selectedFilter) ?? 0 },
                set: { store.send(.selectFilter(PinFilter.allCases[$0])) }
            ),
            size: .xLarge
        )
        .homeGuideDimmed(store.state.isGuidePresented)
        .accessibilityIdentifier("Home.filterBar")
    }

    // MARK: - 빈 상태 본문 (표시할 카드 0장)

    /// 일러스트 + 카피 + "공동방 만들기" CTA. 헤더·필터는 mainContent 가 공통으로 그린다.
    /// CTA 는 공동방 유무와 무관하게 항상 노출한다(팀 정책 — PRD [SYS-009] Flow D 와는 다름).
    private var emptyStateBody: some View {
        VStack(spacing: 24) {   // Figma `Frame 95`(5073:100182) gap 24
            Image(dsImage: "homeEmptyStateIllustration")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)   // Figma `image 77`(5073:100183)
                .accessibilityIdentifier("Home.emptyState.illustration")

            VStack(spacing: 8) {
                Text("공동방을 생성해보세요!")
                    .mhTypography(.title3Bold)
                    .foregroundStyle(.mhPrimaryNormal)

                // 시안은 한 텍스트의 두 줄이지만 `Text` 하나에 `\n` 으로 넣으면 이 계층에서
                // 한 줄로 잘린다(`"…어디였지?"…`). 줄마다 Text 를 두면 그대로 두 줄로 선다.
                VStack(spacing: 0) {
                    Text("\"저번에 말한 거기가 어디였지?\"")
                    Text("더 이상 묻지 마세요.")
                }
                .mhTypography(.label1NormalRegular)
                .foregroundStyle(.mhLabelAlternative)
                .fixedSize(horizontal: false, vertical: true)
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
        .padding(.horizontal, 20)
        .padding(.top, 71)   // Figma: 필터바 하단(248) → 일러스트 상단(319)
    }

    // MARK: - 소진 본문 (모든 방의 장소를 다 봤을 때)

    /// Figma `002-3 모든 카드를 다 봤을 때`(3388:199413) — 일러스트 + 카피만. 덱을 다시 채우는
    /// CTA("장소 더 보기")는 PRD 6.0.0 에서 스펙아웃돼 이 화면에 버튼이 없다(FR-014).
    /// 헤더·필터는 mainContent 가 공통으로 그린다.
    private var allViewedBody: some View {
        VStack(spacing: 24) {   // Figma `5073:101117` gap 24
            Image(dsImage: "homeAllViewedIllustration")
                .resizable()
                .scaledToFit()
                .frame(width: 209, height: 209)   // Figma `5073:101118`
                .accessibilityIdentifier("Home.allViewed.illustration")

            Text("모든 장소를 다 봤어요!")
                .mhTypography(.headline2Medium)
                .foregroundStyle(.mhLabelNeutral)
                .accessibilityIdentifier("Home.allViewed.copy")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 127)   // Figma: 필터바 하단(248) → 일러스트 상단(375)
        .accessibilityIdentifier("Home.allViewed")
    }

// MARK: - 마스코트 캐릭터

    /// 마스코트 오른쪽으로 살짝 보이는 세로 바 (Figma `Rectangle 6323`, node 4071-99611).
    /// 8×148, 화면 우측 끝에 붙고 상단 34(= 시안 78 − 상태바 44). 화면 밖으로 나가는 우측 모서리는 각지고
    /// 안쪽(좌측) 모서리만 라운드 3.961 ≈ 4.
    private var mascotBar: some View {
        UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4, style: .continuous)
            .fill(Color.mhCoolNeutral80)
            .frame(width: 8, height: 148)
            .padding(.top, 34)
            .accessibilityHidden(true)   // 장식 — 읽어줄 내용이 없다
    }

    private var mascotCharacter: some View {
        // 방 캐릭터 — 보는 사람이 아니라 **보고 있는 방**을 나타낸다(FR-021). 방을 바꾸면 함께 바뀐다.
        HomeMascotView(mascot: HomeMascotPalette.mascot(of: store.state.currentRoom?.color))
            .contentShape(Rectangle())
            .onTapGesture { store.send(.tapRoomBadge) }   // 정책: 방 캐릭터 탭 → 방 선택 바텀 시트 토글(열려 있으면 닫는다)
            .accessibilityIdentifier("Home.mascot")
    }

    /// 방 변경 툴팁 — 마스코트(방 캐릭터) 왼쪽에서 오른쪽 화살표로 캐릭터를 가리킨다(Figma Tooltip, position .left).
    /// 상단 우측 고정 배치로 디자인 좌표(화살표 ≈ 상단, 마스코트 왼쪽 가장자리)에 맞춘다.
    @ViewBuilder
    private var roomChangeTooltip: some View {
        // 식별은 id, 표시 문구는 그 id 로 rooms 에서 방을 찾아 파생한다.
        if let roomID = store.state.changedRoomToastID,
           let room = store.state.rooms.first(where: { $0.id == roomID }) {
            // 공동방 "…방이에요." / 개인방 "내 장소예요."
            // Figma 002-5-1(node 2809-143382)의 Tooltip 인스턴스: x=77, y=76, 166×56 →
            // top = 76 − 상태바 44 = 32(뱃지 행과 같은 줄), 우측 인셋 = 375 − (77+166) = 132,
            // 폭은 166 고정이라 긴 방 이름은 hug 하지 않고 그 안에서 줄바꿈한다(시안이 2줄).
            // 오른쪽 끝(243)은 덱 끝 예고 툴팁과 같다 — 둘 다 마스코트를 가리키는 같은 자리다.
            MHTooltip(room.homeToastText, position: .left, maxWidth: 166)
                .padding(.top, 32)
                .padding(.trailing, 132)
                .transition(.opacity)
                // UX-003: 툴팁은 떠 있는 동안 조작을 막지 않는다 — 아래의 방 뱃지·마스코트가 계속 눌린다.
                .allowsHitTesting(false)
                .accessibilityIdentifier("Home.roomChangeToast")
        }
    }

}

// MARK: - 필터 표기

/// 필터 칩 라벨 (Figma 002-1-1 Category). 도메인 값 → 화면 표기 매핑은 Feature 책임.
private extension PinFilter {
    var chipTitle: String {
        switch self {
        case .recommended: "꾹 Pick"
        case .latest: "최신순"
        case .nearby: "가까운순"
        }
    }
}

// MARK: - 마스코트

/// 홈 우상단에서 살짝 걸쳐 보이는 방 마스코트.
/// Figma `Group 283`(4071-99610): 126×164, 우측 화면 끝에 붙고 **헤더(상태바) 하단에서 10** —
/// 시안 상단 54 = 상태바 44 + 10 (002-2-3 ① "토끼 캐릭터는 헤더 하단을 기준으로 10px 간격을 두고 배치한다").
/// 기울기가 에셋에 반영돼 있어 rotationEffect 로 돌리지 않는다(예전 에셋은 정면이라 코드에서 돌렸다).
///
/// 좌우 반전은 시안의 그룹 변환이다 — 익스포트되는 건 반전 전 원본이라 여기서 뒤집어야 시안과 같다.
/// (시안에서 그룹은 x 249…375 인데 자식 좌표가 367·375 로 잡히는 게 그 반전의 흔적)
///
/// 소품은 지금 보고 있는 **방의 대표 색**을 따른다(``HomeMascotPalette``). 13종이 **몸통을 공유**하므로 눈 구멍을
/// 메우는 오버레이는 색과 무관하게 한 장(`homeMascotEyes`)으로 족하다.
struct HomeMascotView: View {
    let mascot: MHHomeMascot

    var body: some View {
        ZStack {
            // 마스코트 눈은 채워진 흰 도형이 아니라 **뚫린 구멍**이라, 뒤에 있는 것이 그대로 비친다.
            // 방 리스트 딤 위에 마스코트를 얹어도 이 구멍으로 딤이 새어 눈만 어두워진다 —
            // 구멍 자리에 화면 배경색을 미리 깔아 막는다. (배경색은 시안에서 눈이 캔버스로 읽히는 것과 같다)
            Image(dsImage: "homeMascotEyes")
                .renderingMode(.template)
                .resizable()
                .frame(width: 126, height: 164)
                .foregroundStyle(Color.mhBackgroundNormalAlternative)

            Image(mascot)
                .resizable()
                .frame(width: 126, height: 164)
        }
        .scaleEffect(x: -1)   // 두 겹을 함께 뒤집어야 눈 자리가 어긋나지 않는다
        .padding(.top, 10)
    }
}

// MARK: - Preview

#Preview("데이터 있을 때") {
    HomeContentView(
        store: HomeStore(
            HomeState(rooms: [
                Room(
                    id: "1", type: .shared, name: "맛집 탐방", description: nil,
                    color: .red, ownerId: "o",
                    createdAt: .now, pinCount: 3, memberCount: 2, users: []
                ),
            ]),
            reduce: homeReducer(
                fetchRooms: PreviewFetchRooms(),
                fetchHomeCards: PreviewFetchHomeCards(),
                currentLocation: PreviewCurrentLocation(),
                lastViewedRoom: PreviewLastViewedRoom(),
                homeGuide: PreviewHomeGuide(),
                savePin: PreviewSavePin(),
                recordPinAccess: PreviewRecordPinAccess(),
                fetchShareTargets: PreviewShareTargets()
            )
        )
    )
}

#Preview("빈상태 A") {
    HomeContentView(
        store: HomeStore(
            HomeState(),
            reduce: homeReducer(
                fetchRooms: PreviewFetchRooms(),
                fetchHomeCards: PreviewFetchHomeCards(),
                currentLocation: PreviewCurrentLocation(),
                lastViewedRoom: PreviewLastViewedRoom(),
                homeGuide: PreviewHomeGuide(),
                savePin: PreviewSavePin(),
                recordPinAccess: PreviewRecordPinAccess(),
                fetchShareTargets: PreviewShareTargets()
            )
        )
    )
}

/// 프리뷰 전용 UseCase. load 액션을 보내도 빈 배열을 반환한다.
private struct PreviewFetchRooms: FetchRoomsUseCase {
    func execute() async throws -> [Room] { [] }
}

private struct PreviewShareTargets: FetchShareTargetsUseCase {
    func execute(placeID: PlaceID) async throws -> [ShareTarget] { [] }
}

/// 프리뷰 전용 — 마지막으로 본 방 기록 없음(항상 최초 실행처럼 첫 방부터).
private struct PreviewLastViewedRoom: LastViewedRoomUseCase {
    func load() async -> String? { nil }
    func save(roomID: String) async {}
}

/// 프리뷰 전용 — 가이드는 이미 본 것으로 둬 프리뷰를 가리지 않는다.
private struct PreviewHomeGuide: HomeGuideUseCase {
    func hasSeen() async -> Bool { true }
    func markSeen() async {}
}

/// 프리뷰 전용 — 접근 기록을 보내지 않는다.
private struct PreviewRecordPinAccess: RecordPinAccessUseCase {
    func execute(pinID: PinID) async throws {}
}

/// 프리뷰 전용 — 저장은 아무것도 하지 않는다.
private struct PreviewSavePin: SavePinToRoomsUseCase {
    func execute(pinID: PinID, roomIDs: Set<String>) async throws {}
}

/// 프리뷰 전용 핀 UseCase. 빈 배열을 반환한다(카드 덱 없이 셸만 확인).
private struct PreviewFetchHomeCards: FetchHomeCardsUseCase {
    func execute(room: Room, filter: PinFilter, origin: Coordinate?) async throws -> [Pin] { [] }
}

/// 프리뷰 전용 — 측위하지 않는다(가까운순 덱을 열지 않으므로 닿지 않는다).
private struct PreviewCurrentLocation: CurrentLocationUseCase {
    func execute() async -> CurrentLocationResult { .permissionDenied }
}
