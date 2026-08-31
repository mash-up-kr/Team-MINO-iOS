import Domain
import FlowCoordination
import MVI
import PlaceDetailUI
import RoomCreationUI
import RoomShareUI
import SwiftUI

/// 홈 탭 flow. 방 생성 등 하위 화면이 추가되면 Route 를 확장한다.
public enum HomeRoute: Hashable {
    /// 공동방 만들기 (RoomCreationUI.RoomFormView) — 방 리스트 시트의 "방 만들기" 진입.
    case createRoom
}

/// 지도 카메라를 내 위치로 옮겨 달라는 요청(005-1 현위치 버튼).
///
/// 좌표만 들지 않고 ``ordinal`` 을 함께 두는 이유는 **같은 자리를 다시 요청하는 경우** 때문이다.
/// 지도를 손으로 옮긴 뒤 현위치를 다시 누르면 좌표는 그대로라 값이 안 바뀌고, 그러면 뷰가
/// 갱신되지 않아 카메라가 돌아오지 않는다. 요청마다 달라지는 번호를 실어 "다시 눌렀다" 를
/// 값으로 만든다.
struct HomeMapFocus: Equatable {
    let coordinate: Coordinate
    let ordinal: Int
}

/// 탭 flow 는 앱 생존 내내 유지되므로 종료가 없다 — Output = Never.
@Observable
@MainActor
public final class HomeCoordinator: Coordinator {
    public var path: [HomeRoute] = []
    public var sheet: Never? = nil
    public var cover: Never? = nil
    public let finish = FlowFinish<Never>()

    /// 열려 있는 장소 상세의 핀 (nil = 닫힘). 커버의 표시 항목이라 SwiftUI 가 닫힐 때 nil 을
    /// 되쓴다 — "열렸나" 플래그를 따로 두면 그 플래그와 핀이 어긋날 짝이 생긴다.
    public var selectedPin: Pin? {
        didSet {
            guard selectedPin?.id != oldValue?.id else { return }
            // 지도는 이 핀이 열려 있는 동안에만 존재한다 — 다른 장소를 열거나 닫으면 이전 현위치
            // 요청이 남아 새 장소가 화면 밖에 놓이는 일이 없도록 함께 비운다.
            mapFocus = nil
            // Store 를 **핀과 같은 순간에** 만든다. 뷰의 `.task` 에서 만들면 시트가 올라오기
            // 시작한 뒤에야 콘텐츠가 채워져, 컨테이너만 올라오고 내용은 뒤늦게 제자리에 나타난다.
            placeDetailStore = selectedPin.map { makePlaceDetailStore(pin: $0) }
            if selectedPin != nil { placeDetailEpoch += 1 }
        }
    }

    /// 장소 상세를 몇 번째로 여는지. 화면이 시트의 `.id` 로 써서 **표시마다 새 identity** 를 만든다.
    ///
    /// 핀 id 로는 부족하다 — 같은 카드를 다시 열면 값이 같아 SwiftUI 가 이전 시트를 재사용하고,
    /// 그러면 콘텐츠가 등장 전환에 참여하지 않아 컨테이너만 올라오는 어긋난 연출이 된다.
    public private(set) var placeDetailEpoch = 0

    /// 열려 있는 장소 상세의 Store. ``selectedPin`` 과 수명을 같이한다 — 시트 **밖**의 지도 위
    /// 현위치 버튼도 같은 Store 로 액션을 보내야 해서 화면이 아니라 여기서 든다.
    public private(set) var placeDetailStore: PlaceDetailStore?

    /// 「다른 방에 공유」 시트(011-1)로 공유하려는 장소 (nil = 닫힘).
    ///
    /// 장소 상세를 **닫지 않는다** — 시트가 상세·지도 위에 얹혀야 사용자가 어디서 공유를 눌렀는지
    /// 유지된다(저장 탭이 같은 방식이다). 항목 자체가 시트의 표시 항목이라 닫히면 SwiftUI 가
    /// nil 을 되쓴다.
    public var sharingPin: Pin?

    /// 공유 시트 **위에** 커버로 띄운 공동방 만들기 자식 flow (기획 011-1 ③).
    /// 부모가 strong 으로 들고, 닫히면 SwiftUI 가 nil 을 되쓴다.
    var shareCreateRoomChild: HomeShareCreateRoomCoordinator?

    /// 지금 방을 **사용자가 직접 골랐는가**
    /// 지도가 장소 중심(``PlaceMapCameraMode/centered(_:)``) 대신 비출 자리. 현위치 버튼이 세운다.
    private(set) var mapFocus: HomeMapFocus?

    /// ``HomeMapFocus/ordinal`` 에 찍을 다음 번호. 표시에 쓰이지 않아 관찰 대상이 아니다.
    @ObservationIgnored private var mapFocusCount = 0

    /// 탭바 자체를 레이아웃에서 빼야 하는(공간까지 없애는) 전체화면 상태인가 — MainTabView 가 본다.
    /// 공동방 만들기(createRoom)가 push 되면 자체 상단바를 가진 전체 화면이라 탭바를 감춘다.
    ///
    /// 방 리스트 시트는 여기 넣지 않는다 — 시트 표시 중 탭바를 safeAreaInset 에서 넣다 빼면 reflow 가
    /// 시트 애니메이션과 어긋나 깜빡인다. 대신 탭바를 자리에 둔 채 불투명도만 0 으로 페이드해
    /// (isRoomListPresented) 그 뒤의 홈 콘텐츠 딤이 비치게 한다 → 탭바 자리도 딤 처리된다.
    ///
    /// 장소 상세도 여기 해당한다 — 뒤에 지도를 깔고 그 위에 시트가 올라오는 화면이라(저장 탭의
    /// 장소 상세와 같은 모양) 탭바가 남으면 시트 하단이 그만큼 가린다. 시트가 아니라 **지도까지
    /// 포함한 화면 전체**가 바뀌는 전환이라 방 리스트 시트와 달리 reflow 깜빡임 문제가 없다.
    public var isFullBleedContentPresented: Bool {
        !path.isEmpty || selectedPin != nil
    }

    /// 방 리스트 시트가 떠 있는가 — MainTabView 가 탭바를 딤 뒤로 페이드시킬 때 본다.
    public var isRoomListPresented: Bool {
        homeStore?.state.isRoomListPresented ?? false
    }

    /// `다른 방 저장` 의 「홈 방 시트」가 떠 있는가 — 이 시트도 시스템 스크림을 끄고 딤을 직접 깔아서,
    /// 방 변경과 같은 이유로 MainTabView 가 탭바를 딤 뒤로 페이드시킬 때 본다.
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
        let store = Store(
            HomeState(),
            reduce: homeReducer(
                fetchRooms: deps.fetchRooms,
                fetchHomeCards: deps.fetchHomeCards,
                currentLocation: deps.currentLocation,
                lastViewedRoom: deps.lastViewedRoom,
                homeGuide: deps.homeGuide,
                savePin: deps.savePin,
                fetchProfile: deps.fetchProfile,
                recordPinAccess: deps.recordPinAccess
            ),
            handle: { [weak self] in self?.handle($0) }
        )
        homeStore = store
        return store
    }

    /// 장소 상세 Store 팩토리 (Figma 002-1-1).
    ///
    /// 홈 진입이므로 카드가 달고 있던 라벨을 그대로 넘긴다 — "홈 카드에서 진입한 경우에만 해당
    /// 카드의 라벨을 장소 상세 상단에 동일하게 노출한다"(002-1-1 ①).
    func makePlaceDetailStore(pin: Pin) -> PlaceDetailStore {
        PlaceDetailUI.makePlaceDetailStore(
            pin: pin,
            label: pin.category,
            deps: deps,
            handle: { [weak self] in self?.handle($0) }
        )
    }

    /// 「다른 방에 공유」 시트 Store 팩토리 (011-1).
    func makeRoomShareStore(pin: Pin) -> RoomShareStore {
        Store(
            RoomShareState(pinID: pin.id, placeID: pin.place.id),
            reduce: roomShareReducer(fetchTargets: deps.fetchShareTargets, savePin: deps.savePin),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    func handle(_ nav: RoomShareNav) {
        switch nav {
        case .didSave:
            sharingPin = nil
            homeStore?.send(.sharedToOtherRooms)   // 013-2 저장 완료 토스트
        case .goToCreateRoom:
            // 시트를 닫지 않는다 — 자식이 시트 위를 덮고, 끝나면 시트가 그 자리에 그대로 있다.
            shareCreateRoomChild = HomeShareCreateRoomCoordinator(deps: deps)
        }
    }

    /// 공동방 만들기 Store 팩토리.
    func makeRoomFormStore() -> RoomFormStore {
        RoomCreationUI.makeRoomFormStore(
            .create(create: deps.createRoom),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    // MARK: - Navigation Routing

    func handle(_ nav: HomeNav) {
        switch nav {
        case .goToCreateRoom:
            push(.createRoom)
        case .openPlaceDetail(let pin):
            selectedPin = pin
        }
    }

    func handle(_ nav: PlaceDetailNav) {
        switch nav {
        case .close:
            selectedPin = nil

        case .share(let pin):
            // 상세를 **닫지 않는다** — 011-1 시트가 지도·상세 위에 얹힌다(저장 탭과 같은 모양).
            sharingPin = pin

        case .focusMyLocation(let coordinate):
            mapFocusCount += 1
            mapFocus = HomeMapFocus(coordinate: coordinate, ordinal: mapFocusCount)

        case .openSavedRooms:
            // TODO: 저장 탭에서 이 버튼은 **보고 있는 방을 갈아탄다**(`ArchiveCoordinator.selectSavedRoom`).
            // 홈에서 같은 일을 하면 `currentRoom` 커서가 옮겨가 카드 덱이 재조회되는데, 그건
            // "상세를 닫으면 보던 덱이 그대로" 라는 홈의 전제와 충돌한다. 무엇을 해야 할지
            // 기획 확인 후 별도 작업으로 정한다 — 그때까지 버튼 자체를 띄우지 않으므로
            // (``HomeTabView`` 의 부유 버튼 줄) 이 전환은 도달하지 않는다.
            break
        }
    }

    func handle(_ nav: RoomFormNav) {
        switch nav {
        case .didSubmit, .didCancel, .didSkip:
            // 저장은 폼이 이미 끝냈다 — 여기 오면 서버에 반영된 뒤다. 취소도 같은 자리로 돌아간다.
            pop()
        }
    }
}
