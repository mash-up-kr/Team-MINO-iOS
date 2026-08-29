import DesignSystem
import Domain
import ProfileSetupUI
import SavePostUI
import SwiftUI

/// 홈 셸 콘텐츠. 방 뱃지 헤더 + 타이틀 + 필터바 + (카드 덱 자리 | 빈상태 A).
struct HomeContentView: View {
    let store: HomeStore

    // 플로팅 "더 보기" 버튼은 여기(NavigationStack 안)가 아니라 HomeTabView 의 스택에 둔다 —
    // NavigationStack 이 상위 safeAreaInset(탭바)을 콘텐츠에 전파하지 않아, 안에 두면 탭바에 가린다.
    var body: some View {
        ZStack(alignment: .topTrailing) {
            guideBackgroundWash  // 홈 가이드 딤 — 콘텐츠 아래(배경색 위)
            mainContent
            roomListDim          // 방 리스트 열릴 때 — 마스코트 아래(홈 콘텐츠만 덮는다)
            if store.state.showsRoomIdentity {
                // 시안에서 바와 캐릭터는 한 그룹(Group 283)이라 함께 넣고, 캐릭터를 바 위에 얹는다.
                mascotBar        // 딤 위 — 밝게 유지. 개인방만 있고 비었을 때만 숨김 (Figma 002-6-1)
                mascotCharacter
            }
            roomChangeTooltip
            deckEndingTooltip
            savePostDim          // 게시물 저장 시트 딤 — 마스코트 위(시안은 화면 전체가 딤)
        }
        .animation(.easeInOut(duration: 0.2), value: store.state.isGuidePresented)   // 루트의 가이드 페이드와 같은 속도
        .animation(.easeInOut(duration: 0.5), value: store.state.changedRoomToastID)
        // 시안 ②의 "서서히 (점차 투명도가 낮아지며) 사라짐" — 페이드 자체가 사라지는 방식이라 명시한다.
        .animation(.easeInOut(duration: 0.5), value: store.state.deckEndingToastFilter)
        .animation(.easeInOut(duration: 0.3), value: store.state.isRoomListPresented)
        .animation(.easeInOut(duration: 0.3), value: store.state.savePost != nil)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.mhBackgroundNormalAlternative)
        // 카드 더보기 메뉴를 화면 최상위에 호스팅 — 카드가 발행한 앵커에 스크림+메뉴를 얹는다
        // (콘텐츠 크기 카드가 못 만드는 화면 전체 바깥탭 스크림을 화면 레벨에서 정확한 z-order 로 그린다).
        .mhHomeCardMenuHost()
        .task { store.send(.load) }
        // 마스코트 색은 방·덱 조회와 따로 받는다(HomeAction.loadMyAvatar 주석). 탭을 오갈 때마다
        // 이 뷰가 새로 만들어지므로, 마이페이지에서 아바타를 바꾸고 돌아오면 여기서 다시 읽힌다.
        .task { store.send(.loadMyAvatar) }
        .task(id: store.state.changedRoomToastID) {
            // 방 변경 툴팁은 5초 뒤 사라진다(정책). 새 툴팁이 뜨면 방 id 가 바뀌어 타이머가 재시작된다.
            // dismiss 는 이 타이머가 세운 방 id 를 실어 보낸다 — 5초 경계에서 방을 바꾸면
            // 이전 타이머의 dismiss 가 새 방 툴팁을 지우지 않도록 reducer 가 id 로 방어한다.
            guard let roomID = store.state.changedRoomToastID else { return }
            try? await Task.sleep(for: .seconds(5))
            store.send(.dismissRoomToast(roomID))
        }
        .task(id: store.state.deckEndingToastFilter) {
            // 덱 끝 예고 툴팁은 3초 뒤 스스로 사라진다(시안 ②). 방 변경 툴팁과 같은 방어 —
            // 3초가 도는 사이 기준이 바뀌면 reducer 가 기준 불일치로 이전 dismiss 를 무시한다.
            guard let filter = store.state.deckEndingToastFilter else { return }
            try? await Task.sleep(for: .seconds(3))
            store.send(.dismissDeckEndingToast(filter))
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
    /// `presentationBackgroundInteraction` 으로 끄고 여기서 직접 깐다(방 리스트 시트와 같은 방식).
    /// 탭바 자리는 이 딤이 닿지 않으므로(딤이 탭바보다 아래 레이어) `MainTabView` 가 탭바를
    /// 페이드시켜 뒤의 딤이 비치게 한다 — iOS 26 은 시트를 띄워 그려 시트 아래로 탭바가 드러난다.
    ///
    /// 뷰 트리에 **항상** 두고 opacity 만 0↔1 로 애니메이션한다 — 조건부 삽입/제거는 사라지는 순간
    /// z-order 가 흔들려 콘텐츠가 딤 위로 번쩍인다(roomListDim 과 같은 이유).
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

    /// 게시물 저장 바텀시트. Figma `013-1-3`(node 2862:177988) — 마크업은 홈과 익스텐션이 함께 쓰는
    /// ``SavePostSheet`` 가 그리고, 여기서는 시트 컨테이너(높이·그래버 숨김)만 맡는다.
    @ViewBuilder
    private var savePostSheet: some View {
        if let savePost = store.state.savePost {
            let rooms = store.state.rooms.map(SavePostRoom.init(_:))
            SavePostSheet(
                rooms: rooms,
                checkedRoomIDs: savePost.checkedRoomIDs,
                disabledRoomIDs: savePost.alreadySavedRoomIDs,
                canSubmit: savePost.canSubmit,
                identifierPrefix: "Home.savePost",
                onToggleRoom: { store.send(.toggleSavePostRoom($0)) },
                onSave: { store.send(.tapSavePost) }
            )
            // safeAreaBottom 0 — 시스템 시트가 하단 인셋을 이미 넣어 준다. detent 높이도 같은 이유로
            // 홈 인디케이터를 뺀 값이다(`.height` 는 안전영역 **위쪽** 높이).
            .presentationDetents([.height(detentHeight(roomCount: rooms.count))])
            .presentationDragIndicator(.hidden)   // 그래버는 시안대로 시트 안에서 직접 그린다
            .presentationCornerRadius(20)         // 시안 radius 20 (시스템 기본 10 과 다름)
            .presentationBackground(.mhBackgroundElevatedNormal)
            // 시스템 스크림 제거 — 딤은 시안 색으로 프리젠터가 직접 그린다(savePostDim).
            .presentationBackgroundInteraction(.enabled(upThrough: .height(detentHeight(roomCount: rooms.count))))
        }
    }

    /// 홈은 단계 없이 `full` 하나다 — peek/full 드래그는 013-1 ① 의 **외부 공유** 시트 규칙이고
    /// 홈 진입에는 대응 시안이 없다. 시스템 시트가 하단 인셋을 넣어 주므로 safeAreaBottom 은 0.
    private func detentHeight(roomCount: Int) -> CGFloat {
        SavePostSheetMetrics.height(.full, roomCount: roomCount, safeAreaBottom: 0)
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

    /// 방 리스트가 열릴 때 홈 콘텐츠 위에 까는 딤(Figma `rgba(0,0,0,0.7)`).
    /// 마스코트 아래 레이어라 마스코트는 딤에 안 덮인다. 탭하면 시트를 닫는다.
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
    /// 가이드가 떠 있을 때: 카드 덱은 **맨 앞 카드만** 딤 위에 남기고(스포트라이트), 카드가 없는
    /// 상태(로딩·빈 상태·소진)는 가리킬 대상이 없으므로 본문 통째로 딤 뒤로 물러난다.
    @ViewBuilder
    private var contentBody: some View {
        // 기준을 바꿔 덱을 받는 중이면(캐시 없을 때만) 로딩으로 둔다 — 그 사이 빈 상태·소진 화면이
        // 한 프레임 끼어들면 화면이 깜빡인다. 받아 둔 기준으로 되돌아갈 땐 즉시 전환이라 여기 안 걸린다.
        if store.state.isLoading || (store.state.isDeckLoading && store.state.pins.isEmpty) {
            Spacer()
            ProgressView()
                .frame(maxWidth: .infinity)
                .homeGuideDimmed(store.state.isGuidePresented)
                .accessibilityIdentifier("Home.state.loading")
            Spacer()
        } else if store.state.showsEmptyState {
            emptyStateBody
                .homeGuideDimmed(store.state.isGuidePresented)
        } else if store.state.hasViewedAllPlaces {
            allViewedBody
                .homeGuideDimmed(store.state.isGuidePresented)
        } else {
            CardDeckView(
                pins: store.state.pins,
                currentIndex: store.state.currentCardIndex,
                canReturnToPreviousDeck: store.state.canReturnToPreviousFilter,
                previousDeckLastCard: store.state.previousDeckLastPin,
                onSwipeForward: { store.send(.swipeForward) },
                onSwipeBackward: { store.send(.swipeBackward) },
                onTapCard: { store.send(.tapCard($0)) },
                onSaveToOtherRoom: { store.send(.tapSaveToOtherRoom($0)) },
                isGuidePresented: store.state.isGuidePresented
            )
            .padding(.top, 112)   // 앞 카드 고정 위치. 풀 덱일 때 뒤 카드 최상단이 필터 32pt 아래(112−80)에 오도록
            .accessibilityIdentifier("Home.cardDeck")
            Spacer()
        }
    }

    // MARK: - 헤더 (방 뱃지 or 로고 + 타이틀)

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.state.showsRoomIdentity, let room = store.state.currentRoom {
                MHContentBadge(room.homeDisplayName, size: .medium)   // 공동방 "…방" / 개인방 "내 장소"
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
        VStack(spacing: 20) {
            illustrationPlaceholder(identifier: "Home.emptyState.illustration")

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

    // MARK: - 소진 본문 (모든 방의 장소를 다 봤을 때)

    /// Figma 002-3 「모든 카드를 다 봤을 때」 — 일러스트 + 카피만. CTA("장소 더 보기")는 카드 덱일 때와 같은
    /// 자리(탭바 위 플로팅)라 HomeTabView 가 그린다. 헤더·필터는 mainContent 가 공통으로 그린다.
    private var allViewedBody: some View {
        VStack(spacing: 20) {   // Figma: 일러스트 하단(572) → 카피 상단(592) = base lg 20
            Image(dsImage: "homeAllViewedIllustration")
                .resizable()
                .scaledToFit()
                .frame(width: 249, height: 249)
                .accessibilityIdentifier("Home.allViewed.illustration")

            Text("꾹 눌러둔 장소를 모두 둘러봤어요")
                .mhTypography(.label1NormalRegular)
                .foregroundStyle(.mhPrimaryNormal)
                .accessibilityIdentifier("Home.allViewed.copy")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 75)   // Figma: 필터바 하단(248) → 일러스트 상단(323)
        .accessibilityIdentifier("Home.allViewed")
    }

    /// 빈 상태 일러스트 자리(249×249)를 잡는 placeholder. 소진 화면은 실 에셋으로 교체됐고,
    /// 빈 상태는 시안이 아직 정리되지 않아 자리만 잡아 둔다 — 에셋이 나오면 이 헬퍼를 Image 로 교체한다.
    private func illustrationPlaceholder(identifier: String) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.mhFillNormal)   // 화면 배경(alternative)과 구분되는 색
            .frame(width: 249, height: 249)   // 소진 화면 일러스트와 같은 크기
            .overlay {
                Text("이미지 교체 예정")
                    .mhTypography(.body2NormalMedium)
                    .foregroundStyle(.mhLabelAlternative)
            }
            .accessibilityIdentifier(identifier)
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
        HomeMascotView(mascot: AvatarPalette.homeMascot(of: store.state.myAvatarColor))
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
                .accessibilityIdentifier("Home.roomChangeToast")
        }
    }

    /// 덱 끝 예고 툴팁 — 현재 기준의 남은 카드가 2장 이하일 때 "곧 …으로 이동해요!" 로 다음 기준 전환을
    /// 미리 알린다 (Figma 002-2-3 ②, node 4071-99859). 3초 뒤 서서히 사라진다.
    ///
    /// 방 변경 툴팁과 같은 줄(상단 32)이라 둘이 동시에 서면 겹친다 — 방 변경 툴팁은 사용자가 방금 한
    /// 조작(방 선택)에 대한 응답이라 그쪽을 우선하고, 이 예고는 물러난다(주변 안내라 다음 기회가 있다).
    @ViewBuilder
    private var deckEndingTooltip: some View {
        if store.state.changedRoomToastID == nil, store.state.deckEndingToastFilter != nil {
            // 문구는 "다음에 갈 곳" — 이 방에 미확인 정렬이 남아 있으면 그 칩 이름, 없으면 다음 방이다
            // (Figma 002-2-3 세 장: 꾹 Pick→최신순 / 최신순→가까운순 / 가까운순→다음 방).
            MHTooltip(store.state.nextUnviewedFilter.map { "곧 \($0.chipTitle)으로 이동해요!" }
                        ?? "곧 다음 방으로 이동해요!",
                      position: .left)
                .fixedSize()
                // Figma Tooltip 인스턴스: x=78, y=75.9, 165×36 →
                // top = 75.9 − 상태바 44 ≈ 32(방 변경 툴팁과 같은 줄), 우측 인셋 = 375 − (78+165) = 132.
                .padding(.top, 32)
                .padding(.trailing, 132)
                .transition(.opacity)
                .accessibilityIdentifier("Home.deckEndingToast")
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
/// 소품은 내 프로필 아바타 색을 따른다(`MHHomeMascot`). 13종이 **몸통을 공유**하므로 눈 구멍을
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
                fetchProfile: PreviewFetchProfile()
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
                fetchProfile: PreviewFetchProfile()
            )
        )
    )
}

/// 프리뷰 전용 UseCase. load 액션을 보내도 빈 배열을 반환한다.
private struct PreviewFetchRooms: FetchRoomsUseCase {
    func execute() async throws -> [Room] { [] }
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

/// 프리뷰 전용 — 아바타 색을 고른 적 없는 계정(기본 마스코트).
private struct PreviewFetchProfile: FetchProfileUseCase {
    func execute() async throws -> Profile {
        Profile(id: "preview", nickname: "꾹이", avatarColor: nil, createdAt: nil)
    }
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
