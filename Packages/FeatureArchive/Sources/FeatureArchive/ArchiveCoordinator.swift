import Core
import Domain
import FlowCoordination
import MVI
import RoomCreationUI
import SwiftUI

/// 저장 탭 flow 의 하위 화면. (카드 탭 등 나머지 전환은 아직 없다)
public enum ArchiveRoute: Hashable {
    /// 공동방 만들기 (RoomCreationUI.RoomFormView) — 유도 시트·빈 상태 CTA·헤더 "+" 진입.
    case createRoom
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

    public var isRoomDetailPresented: Bool { selectedRoom != nil }

    /// 탭바 자체를 레이아웃에서 빼야 하는 전체화면 상태인가 — MainTabView 가 본다.
    /// 방 상세 시트, 그리고 자체 상단바를 가진 push 화면(공동방 만들기)이 여기 해당한다.
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
            reduce: roomListReducer(useCase: deps.fetchRooms, promptSnooze: deps.roomCreationPromptSnooze),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    func makeRoomDetailStore(room: Room) -> RoomDetailStore {
        Store(
            RoomDetailState(room: RoomDetailRoom(from: room)),
            reduce: roomDetailReducer(useCase: deps.fetchPins, deletePin: deps.deletePin, room: room),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    func makePlaceDetailStore(pin: Pin) -> PlaceDetailStore {
        Store(
            PlaceDetailState(place: PlaceDetailPlace(from: pin)),
            reduce: placeDetailReducer(
                useCase: deps.fetchPinDetail,
                fetchCurrentMember: deps.currentMember,
                pin: pin
            ),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    /// 다른 방에 공유 시트 Store 팩토리.
    ///
    /// - Parameter location: 공유할 장소. `id` 는 ``RoomDetailLocation/init(from:)`` 이 넣은
    ///   핀 id 라 그대로 ``PinID`` 로 되돌린다.
    func makeRoomShareStore(location: RoomDetailLocation) -> RoomShareStore {
        Store(
            RoomShareState(pinID: PinID(location.id)),
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
            selectedRoom = room
        case .goToCreateRoom:
            push(.createRoom)
        }
    }

    func handle(_ nav: RoomFormNav) {
        switch nav {
        case .didSubmit, .didCancel, .didSkip:
            // 저장은 폼이 이미 끝냈다 — 여기 오면 서버에 반영된 뒤다. 취소도 같은 자리로 돌아간다.
            pop()
        }
    }

    func handle(_ nav: RoomDetailNav) {
        switch nav {
        case .close:
            selectedRoom = nil
            selectedPin = nil
        case .shareLocation(let location):
            sharingLocation = location
        case .openPlaceDetail(let pin):
            selectedPin = pin
        }
    }

    func handle(_ nav: PlaceDetailNav) {
        switch nav {
        case .close:
            selectedPin = nil
        case .share(let location):
            sharingLocation = location
        }
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

    /// 공유 완료 신호를 읽고 지운다. 두 번째 호출은 `false` — 같은 저장으로 토스트가 두 번 뜨지 않는다.
    func consumeSavedShare() -> Bool {
        defer { savedShare = false }
        return savedShare
    }
}
