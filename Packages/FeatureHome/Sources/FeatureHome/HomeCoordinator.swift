import Domain
import FlowCoordination
import MVI
import RoomCreationUI
import SwiftUI

/// 홈 탭 flow. 방 생성 등 하위 화면이 추가되면 Route 를 확장한다.
public enum HomeRoute: Hashable {
    /// 공동방 만들기 (RoomCreationUI.CreateRoomView) — 방 리스트 시트의 "방 만들기" 진입.
    case createRoom
}

/// 탭 flow 는 앱 생존 내내 유지되므로 종료가 없다 — Output = Never.
@Observable
@MainActor
public final class HomeCoordinator: Coordinator {
    public var path: [HomeRoute] = []
    public var sheet: Never? = nil
    public var cover: Never? = nil
    public let finish = FlowFinish<Never>()

    /// 탭바 자체를 레이아웃에서 빼야 하는(공간까지 없애는) 전체화면 상태인가 — MainTabView 가 본다.
    /// 공동방 만들기(createRoom)가 push 되면 자체 상단바를 가진 전체 화면이라 탭바를 감춘다.
    ///
    /// 방 리스트 시트는 여기 넣지 않는다 — 시트 표시 중 탭바를 safeAreaInset 에서 넣다 빼면 reflow 가
    /// 시트 애니메이션과 어긋나 깜빡인다. 대신 탭바를 자리에 둔 채 불투명도만 0 으로 페이드해
    /// (isRoomListPresented) 그 뒤의 홈 콘텐츠 딤이 비치게 한다 → 탭바 자리도 딤 처리된다.
    public var isFullBleedContentPresented: Bool {
        !path.isEmpty
    }

    /// 방 리스트 시트가 떠 있는가 — MainTabView 가 탭바를 딤 뒤로 페이드시킬 때 본다.
    public var isRoomListPresented: Bool {
        homeStore?.state.isRoomListPresented ?? false
    }

    /// 게시물 저장 시트가 떠 있는가 — 이 시트도 시스템 스크림을 끄고 딤을 직접 깔아서,
    /// 방 리스트와 같은 이유로 MainTabView 가 탭바를 딤 뒤로 페이드시킬 때 본다.
    ///
    /// iOS 26 은 부분 높이 시트를 화면에서 띄워(인셋) 그리기 때문에 시트 아래·옆으로 탭바가 드러난다
    /// — iOS 18 처럼 시트가 바닥까지 덮는다고 보고 이 페이드를 생략하면 그 자리만 딤이 빠진다.
    public var isSavePostPresented: Bool {
        homeStore?.state.savePost != nil
    }

    /// 홈 사용 가이드가 떠 있는가 — 탭바 위까지 덮어야 해서 MainTabView 가 루트에서 그린다.
    public var isGuidePresented: Bool {
        homeStore?.state.isGuidePresented ?? false
    }

    /// 가이드 X 탭 — 루트에서 그리는 오버레이가 홈 상태를 닫도록 위임받는다.
    public func dismissGuide() {
        homeStore?.send(.dismissGuide)
    }

    private let deps: HomeDeps
    /// 홈 Store — 위 isRoomListPresented 가 시트 표시 상태를 읽어 탭바 딤 페이드를 구동한다.
    private var homeStore: HomeStore?

    public init(deps: HomeDeps) {
        self.deps = deps
    }

    // MARK: - Store Factory

    public func makeHomeStore() -> HomeStore {
        let store = HomeStore(
            HomeState(),
            reduce: homeReducer(
                fetchRooms: deps.fetchRooms,
                fetchPins: deps.fetchPins,
                lastViewedRoom: deps.lastViewedRoom,
                homeGuide: deps.homeGuide,
                savePin: deps.savePin
            )
        )
        store.observeNavigation { [weak self] in self?.handle($0) }
        homeStore = store
        return store
    }

    /// 공동방 만들기 Store 팩토리. createRoomReducer 는 의존이 없어 그대로 조립한다(RoomCreationUI 는 UI 전용).
    func makeCreateRoomStore() -> CreateRoomStore {
        let store = CreateRoomStore(CreateRoomState(), reduce: createRoomReducer())
        store.observeNavigation { [weak self] in self?.handle($0) }
        return store
    }

    // MARK: - Navigation Routing

    func handle(_ nav: HomeNav) {
        switch nav {
        case .goToCreateRoom:
            push(.createRoom)
        }
    }

    func handle(_ nav: CreateRoomNav) {
        switch nav {
        case .didCreateRoom, .didSkip:
            // 생성/취소 후 홈으로 복귀. (실제 방 생성 로직은 후속 — 현재 RoomCreationUI 는 UI 전용)
            if !path.isEmpty { path.removeLast() }
        }
    }
}
