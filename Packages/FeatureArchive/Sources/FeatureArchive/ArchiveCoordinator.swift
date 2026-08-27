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
            reduce: roomDetailReducer(useCase: deps.fetchPins, room: room),
            handle: { [weak self] in self?.handle($0) }
        )
    }

    func makePlaceDetailStore(pin: Pin) -> PlaceDetailStore {
        Store(
            PlaceDetailState(place: PlaceDetailPlace(from: pin, now: Date())),
            reduce: placeDetailReducer(pin: pin),
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
}
