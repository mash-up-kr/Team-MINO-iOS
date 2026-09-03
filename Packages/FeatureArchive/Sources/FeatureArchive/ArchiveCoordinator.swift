import Core
import Domain
import FlowCoordination
import MVI
import PlaceDetailUI
import RoomCreationUI
import RoomShareUI
import SwiftUI

/// 저장 탭 flow 의 하위 화면. (카드 탭 등 나머지 전환은 아직 없다)
public enum ArchiveRoute: Hashable {
    /// 공동방 만들기 (RoomCreationUI.RoomFormView) — 유도 시트·빈 상태 CTA·헤더 "+" 진입.
    case createRoom
}

/// 지도 카메라를 내 위치로 옮겨 달라는 요청(005-1 현위치 버튼).
///
/// 좌표만 들지 않고 ``ordinal`` 을 함께 두는 이유는 **같은 자리를 다시 요청하는 경우** 때문이다.
/// 지도를 손으로 옮긴 뒤 현위치를 다시 누르면 좌표는 그대로라 값이 안 바뀌고, 그러면 뷰가
/// 갱신되지 않아 카메라가 돌아오지 않는다. 요청마다 달라지는 번호를 실어 "다시 눌렀다" 를
/// 값으로 만든다 — 상태가 아니라 명령이라 두 요청은 목적지가 같아도 서로 다른 요청이다.
struct ArchiveMapFocus: Equatable {
    let coordinate: Coordinate
    let ordinal: Int
}

/// 탭 flow 는 앱 생존 내내 유지되므로 종료가 없다 — Output = Never.
@Observable
@MainActor
public final class ArchiveCoordinator: Coordinator {
    public var path: [ArchiveRoute] = []
    public var sheet: Never? = nil
    public var cover: Never? = nil
    public let finish = FlowFinish<Never>()

    private let deps: ArchiveDeps

    public private(set) var selectedRoom: Room?

    public private(set) var selectedPin: Pin?

    /// 지도가 핀 맞춤(``PlaceMap/camera(for:focusing:)``) 대신 비출 자리. 현위치 버튼이 세운다.
    ///
    /// 보고 있는 방이 바뀌면 비운다(``showRoom(_:)``) — 새 방의 핀에 다시 맞춰야 하기 때문이다.
    /// 장소 상세를 닫는 것만으로는 비우지 않는다: 사용자가 옮겨 둔 지도를 시트를 닫았다고
    /// 되돌리면 되레 놀란다.
    private(set) var mapFocus: ArchiveMapFocus?

    /// ``ArchiveMapFocus/ordinal`` 에 찍을 다음 번호. 표시에 쓰이지 않아 관찰 대상이 아니다.
    @ObservationIgnored private var mapFocusCount = 0

    public var isRoomDetailPresented: Bool { selectedRoom != nil }

    /// 탭바 자체를 레이아웃에서 빼야 하는 전체화면 상태인가 — MainTabView 가 본다.
    /// 방 상세 시트, 그리고 자체 상단바를 가진 push 화면(공동방 만들기)이 여기 해당한다.
    ///
    /// **방 리스트 시트가 `Full` 로 올라간 상태는 여기 넣지 않는다 — 탭바를 유지한다.**
    /// PRD [SYS-005] Flow B 는 "3단 바텀시트가 `Full` 로 승격된 상태에서는 감춘다" 라고 적혀 있지만,
    /// 시안은 반대로 그려져 있다(`003-1-3 full`·`003-2-3 full` 두 프레임 모두 `Bottom Navigation`
    /// 인스턴스를 y=711/714 에 두고 있다). **시안을 따르기로 확정했다**(담당자 결정 2026-08-30).
    ///
    /// 문서와 어긋나는 쪽이라 여기 적어 둔다 — PRD 만 보고 "버그" 로 판단해 되돌리지 않도록.
    /// 방 상세(`[SCR-005]` "몰입감을 위해 바텀 네비게이션 비노출")는 이와 별개로 계속 감춘다.
    public var isFullBleedContentPresented: Bool {
        isRoomDetailPresented || !path.isEmpty
    }

    var sharingLocation: RoomDetailLocation?

    /// 공유 시트 **위에** 커버로 띄운 공동방 만들기 자식 flow (기획 011-1 ③).
    ///
    /// 부모가 strong 보유한다(`@Observable` 추적 + 수명 관리). 커버를 시트 안에서 띄우므로
    /// (``RoomShareSheet``) 시트는 살아 있고, 돌아오면 고르던 방 선택이 그대로다.
    ///
    /// 이 프로퍼티 자체가 커버의 표시 항목이라 닫히면 SwiftUI 가 여기에 nil 을 되쓴다 —
    /// "표시 상태 ↔ 자식" 을 손으로 맞출 짝이 없어 `onDismiss` 정리 훅을 따로 두지 않는다.
    var shareCreateRoomChild: RoomShareCreateRoomCoordinator?

    /// 저장된 방 시트(014)에 띄울 목록. 목록 자체가 표시 항목이라 "열렸나" 플래그를 따로 두지
    /// 않는다 — 두면 플래그와 목록이 어긋날 짝이 생긴다.
    var savedRooms: SavedRoomsPresentation?

    /// 방 목록이 바뀐 횟수. 껍데기가 이 값의 변화를 보고 방 리스트를 다시 받는다(``ArchiveShellView``).
    ///
    /// 껍데기가 사라졌다 돌아오는 전환(공동방 만들기 push→pop · 탭 복귀)은 `.task` 가 이미 재조회하므로
    /// 여기서 세지 않는다 — 세면 한 번의 복귀에 조회가 두 번 나가고, 두 번째 `.loaded` 가
    /// ``RoomListState/skipsNextCreatePrompt`` 를 이미 쓴 뒤라 취소하고 나온 사용자에게 유도 시트가 뜬다.
    /// **시트가 떠 있어 껍데기가 살아 있는 동안 방이 늘어난 경우**(공유 시트 위 커버에서 방 생성)만 센다.
    private(set) var roomsRevision = 0

    /// 공유 저장이 **성공했을 때만** 서는 1회성 신호. 시트가 닫힌 뒤 껍데기가 소비해 완료 토스트를
    /// 띄운다. X 로 닫거나 저장에 실패하면 서지 않는다 — 그 자리에 완료 토스트가 뜨면 거짓말이 된다.
    /// 관찰 대상이 아니다(소비 시점이 `onDismiss`, 즉 뷰 갱신 중이라 관찰되면 재갱신을 부른다).
    @ObservationIgnored private var savedShare = false

    public init(deps: ArchiveDeps) {
        self.deps = deps
    }

    // MARK: - Store Factories

    public func makeRoomListStore() -> RoomListStore {
        Store(
            RoomListState(),
            reduce: roomListReducer(
                useCase: deps.fetchRooms,
                promptSnooze: deps.roomCreationPromptSnooze,
                currentLocation: deps.currentLocation
            ),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    func makeRoomDetailStore(room: Room) -> RoomDetailStore {
        Store(
            RoomDetailState(room: RoomDetailRoom(from: room)),
            reduce: roomDetailReducer(
                useCase: deps.fetchRoomPins,
                deletePin: deps.deletePin,
                fetchCurrentMember: deps.currentMember,
                currentLocation: deps.currentLocation,
                room: room
            ),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    func makePlaceDetailStore(pin: Pin) -> PlaceDetailStore {
        PlaceDetailUI.makePlaceDetailStore(
            pin: pin,
            // 저장 탭 진입은 라벨을 달지 않는다 (Figma 002-1-1 ① — 홈 카드 진입 전용).
            label: nil,
            deps: deps,
            handle: { [weak self] in self?.handle($0) }
        )
    }

    /// 다른 방에 공유 시트 Store 팩토리.
    ///
    /// - Parameter location: 공유할 장소. `id` 는 ``RoomDetailLocation/init(from:)`` 이 넣은
    ///   핀 id 라 그대로 ``PinID`` 로 되돌린다.
    func makeRoomShareStore(location: RoomDetailLocation) -> RoomShareStore {
        Store(
            RoomShareState(pinID: PinID(location.id), placeID: PlaceID(location.placeID)),
            reduce: roomShareReducer(fetchTargets: deps.fetchShareTargets, savePin: deps.savePin),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    /// 공동방 만들기 Store 팩토리.
    func makeRoomFormStore() -> RoomFormStore {
        RoomCreationUI.makeRoomFormStore(
            .create(create: deps.createRoom),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    // MARK: - Effect Routing

    func handle(_ nav: RoomListNav) {
        switch nav {
        case .openRoomDetail(let room):
            showRoom(room)
        case .goToCreateRoom:
            push(.createRoom)
        case .focusMyLocation(let coordinate):
            focusMap(on: coordinate)
        }
    }

    func handle(_ nav: RoomFormNav) {
        switch nav {
        // spec FR-007 — 만들었으면 방 리스트를 스쳐 그 방 상세로 간다. 여기서는 id 만 세워 두고,
        // 실제 전환은 방 리스트가 재조회로 그 방을 받은 뒤에 낸다(``RoomListAction/openCreatedRoom``).
        case .didSubmit(let roomId):
            createdRoomID = roomId
            pop()
        case .didCancel, .didSkip:
            // 저장은 폼이 이미 끝냈다 — 여기 오면 서버에 반영된 뒤다. 취소도 같은 자리로 돌아간다.
            pop()
        }
    }

    /// 방금 만든 방 id 를 읽고 지운다. 두 번째 호출은 `nil` — 같은 생성으로 상세가 두 번 열리지 않는다.
    func consumeCreatedRoomID() -> String? {
        defer { createdRoomID = nil }
        return createdRoomID
    }

    func handle(_ nav: RoomDetailNav) {
        switch nav {
        case .close:
            showRoom(nil)
            selectedPin = nil
        case .shareLocation(let location):
            sharingLocation = location
        case .openPlaceDetail(let pin):
            selectedPin = pin
        case .editRoom, .leaveRoom:
            // 아직 갈 곳이 없다 — 비워 둔 것이 아니라 도착 화면이 이 PR 범위 밖이다.
            // 방 편집(시안 004-5 방편집_방장)·방 나가기(004-5 나가기_방장 / 나가기_방멤버)는
            // 다른 담당자(유빈·윤지) 스펙이라 그 화면이 생기는 PR 에서 여기에 전환을 붙인다.
            // 그때까지 헤더 케밥은 항목만 닫고 아무 데도 가지 않는다.
            break
        }
    }

    func handle(_ nav: PlaceDetailNav) {
        switch nav {
        case .close:
            selectedPin = nil
        case .share(let pin):
            // 상세는 도메인 핀을 넘긴다 — 공유 시트가 쓰는 표시 모델로 바꾸는 건 이 flow 몫이다.
            sharingLocation = RoomDetailLocation(from: pin)
        case .openSavedRooms(let presentation):
            savedRooms = presentation
        case .focusMyLocation(let coordinate):
            focusMap(on: coordinate)
        }
    }

    /// 현위치 버튼(003-1 ⑦ · 005-1)이 낸 카메라 요청을 세운다. 방 리스트와 장소 상세가 같은 자리를
    /// 쓰므로 한 곳에 둔다 — 두 벌로 두면 한쪽만 고쳐도 컴파일이 통과한다.
    private func focusMap(on coordinate: Coordinate) {
        mapFocusCount += 1
        mapFocus = ArchiveMapFocus(coordinate: coordinate, ordinal: mapFocusCount)
    }

    /// 보고 있는 방을 바꾼다. 지도 카메라 요청(``mapFocus``)은 방과 수명을 같이한다 —
    /// 남겨 두면 새 방을 열어도 카메라가 내 위치에 붙어 그 방의 핀이 화면 밖에 남는다.
    private func showRoom(_ room: Room?) {
        selectedRoom = room
        mapFocus = nil
    }

    // MARK: - 탭 밖에서 들어오는 진입점

    /// 저장 탭 밖(알림 탭 · 앞으로는 딥링크·푸시)에서 방 상세를 연다.
    ///
    /// **조회는 부르는 쪽이 끝내고 온다** — 여기서 id 를 받아 조회하면 실패·로딩 상태가 이 flow 로
    /// 흘러들어오고, 방 상세·장소 상세가 "데이터 없는 상태" 를 새로 표현해야 한다.
    public func open(room: Room) {
        resetToShell()
        showRoom(room)
        selectedPin = nil
    }

    /// 저장 탭 밖에서 장소 상세를 연다. 배경 지도가 `selectedRoom` 에 의존하므로 **방을 함께 받는다** —
    /// 장소만 세우면 빈 지도 위에 시트만 뜬다.
    public func open(pin: Pin, in room: Room) {
        resetToShell()
        showRoom(room)
        selectedPin = pin
    }

    /// 껍데기(지도 + 방 리스트 시트)로 되돌린다.
    ///
    /// 이 Coordinator 는 앱 수명 내내 살아 있어 **탭을 떠나도 push·시트가 남는다.** 공동방 만들기를
    /// push 한 채 알림 탭으로 갔다가 크로스탭으로 돌아오면 그 화면이 목적지를 통째로 덮는다.
    /// 공유 시트·저장된 방 시트도 같다 — 껍데기가 다시 뜨는 순간 재표시된다.
    private func resetToShell() {
        path = []
        sharingLocation = nil
        savedRooms = nil
        shareCreateRoomChild = nil
    }

    /// 014 ② — 고른 방의 장소 상세로. 시트를 닫고 **방만** 갈아끼운다.
    ///
    /// 보고 있던 장소(`selectedPin`)는 그대로 둔다. 같은 장소라도 방마다 핀이 따로인데 저장 API 가
    /// 아직 그 짝을 주지 않아 "그 방 쪽 핀"을 집을 수 없기 때문이다 — 핀을 비우면 시트가 닫혀
    /// "장소상세로 이동한다" 는 기획과 더 멀어진다. API 가 붙으면 그 방의 핀 id 로 함께 갈아끼운다.
    func selectSavedRoom(_ roomID: String) {
        guard let room = savedRooms?.rooms.first(where: { $0.id == roomID }) else { return }
        savedRooms = nil
        showRoom(room)
    }

    func handle(_ nav: RoomShareNav) {
        switch nav {
        case .didSave:
            savedShare = true
            sharingLocation = nil   // 토스트는 시트가 닫힌 뒤 `onDismiss` 에서 뜬다
        case .goToCreateRoom:
            // 시트를 닫지 않는다 — 자식이 시트 위를 덮고, 끝나면 시트가 그 자리에 그대로 있다.
            shareCreateRoomChild = RoomShareCreateRoomCoordinator(deps: deps)
        }
    }

    /// 방 목록이 바뀌었다고 알린다. 지금 부르는 곳은 공유 시트 위 커버의 방 생성뿐이다.
    func roomsDidChange() {
        roomsRevision += 1
    }

    /// 방금 만든 방 id — 껍데기가 방 리스트에 넘겨 그 방 상세로 잇는다(spec FR-007).
    ///
    /// 방 전체가 아니라 id 만 드는 이유는 만들기 화면이 id 만 돌려주기 때문이다
    /// (``RoomFormNav/didSubmit(roomId:)``). 상세는 멤버·장소 수까지 필요해 재조회 응답에서 찾는다.
    private(set) var createdRoomID: String?

    /// 공유 완료 신호를 읽고 지운다. 두 번째 호출은 `false` — 같은 저장으로 토스트가 두 번 뜨지 않는다.
    func consumeSavedShare() -> Bool {
        defer { savedShare = false }
        return savedShare
    }
}
