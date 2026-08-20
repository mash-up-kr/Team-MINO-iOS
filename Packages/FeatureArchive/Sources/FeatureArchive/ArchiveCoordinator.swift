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

    /// 탭바 자체를 레이아웃에서 빼야 하는 전체화면 상태인가 — MainTabView 가 본다.
    /// 공동방 만들기가 push 되면 자체 상단바를 가진 전체 화면이라 탭바를 감춘다(홈 탭과 같은 규칙).
    public var isFullBleedContentPresented: Bool {
        !path.isEmpty
    }

    private let deps: ArchiveDeps

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

    /// 공동방 만들기 Store 팩토리. roomFormReducer 는 의존이 없어 그대로 조립한다(RoomCreationUI 는 UI 전용).
    func makeRoomFormStore() -> RoomFormStore {
        let store = RoomFormStore(RoomFormState(mode: .create), reduce: roomFormReducer())
        store.observeNavigation { [weak self] in self?.handle($0) }
        return store
    }

    // MARK: - Effect Routing

    func handle(_ nav: RoomListNav) {
        switch nav {
        case .goToCreateRoom:
            push(.createRoom)
        }
    }

    func handle(_ nav: RoomFormNav) {
        switch nav {
        case .didSubmit, .didCancel, .didSkip:
            // 생성/취소 후 방 리스트로 복귀. (실제 방 생성 로직은 후속 — 현재 RoomCreationUI 는 UI 전용)
            if !path.isEmpty { path.removeLast() }
        }
    }
}
