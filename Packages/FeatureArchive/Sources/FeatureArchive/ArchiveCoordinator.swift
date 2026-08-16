import Domain
import FlowCoordination
import MVI
import SwiftUI

/// 저장 탭 flow. 아직 하위 화면이 없어 Route 는 비어 있다(카드 탭·"+" 인터랙션 비활성).
public enum ArchiveRoute: Hashable {}

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

    public var isRoomDetailPresented: Bool { selectedRoom != nil }

    var sharingLocation: RoomDetailLocation?

    public init(deps: ArchiveDeps) {
        self.deps = deps
    }

    // MARK: - Store Factories

    public func makeRoomListStore() -> RoomListStore {
        let store = RoomListStore(
            RoomListState(),
            reduce: roomListReducer(useCase: deps.fetchRooms)
        )
        store.observeNavigation { [weak self] in self?.handle($0) }   // 구독·Task 관리는 Store 가 담당
        return store
    }

    func makeRoomDetailStore(room: Room) -> RoomDetailStore {
        let store = RoomDetailStore(
            RoomDetailState(room: RoomDetailRoom(from: room)),
            reduce: roomDetailReducer(useCase: deps.fetchPins, room: room)
        )
        store.observeNavigation { [weak self] in self?.handle($0) }
        return store
    }

    // MARK: - Effect Routing

    func handle(_ nav: RoomListNav) {
        switch nav {
        case .openRoomDetail(let room):
            selectedRoom = room
        }
    }

    func handle(_ nav: RoomDetailNav) {
        switch nav {
        case .close:
            selectedRoom = nil
        case .shareLocation(let location):
            sharingLocation = location
        }
    }
}
