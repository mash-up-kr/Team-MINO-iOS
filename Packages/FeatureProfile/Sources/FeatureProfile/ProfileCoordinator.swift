import FlowCoordination
import MVI
import RoomCreationUI
import SwiftUI

/// 마이 탭 flow 의 하위 화면.
public enum ProfileRoute: Hashable {
    /// 방 편집 (RoomCreationUI.RoomFormView) — 방 상세 더보기 진입.
    case roomEdit
}

/// 탭 flow 는 앱 생존 내내 유지되므로 종료가 없다 — Output = Never.
@Observable
@MainActor
public final class ProfileCoordinator: Coordinator {
    public var path: [ProfileRoute] = []
    public var sheet: Never? = nil
    public var cover: Never? = nil
    public let finish = FlowFinish<Never>()

    /// 방 상세 시트 표시 여부. 시안이 탭바 없는 전체 화면이라 시트가 열려 있는 동안
    /// 앱 루트가 탭바를 감춰야 해서, 탭 화면 내부 상태가 아니라 여기(탭 flow)에 둔다.
    public var isRoomDetailPresented = false

    /// 탭바 자체를 레이아웃에서 빼야 하는 전체화면 상태인가 — MainTabView 가 본다.
    public var isFullBleedContentPresented: Bool {
        isRoomDetailPresented || !path.isEmpty
    }

    /// 편집 화면에 프리필할 방. push 직전에 채운다.
    private var editingRoom: RoomDetailRoom?

    public init() {}

    // MARK: - 방 편집

    func startRoomEdit(_ room: RoomDetailRoom) {
        editingRoom = room
        push(.roomEdit)
    }

    /// 방 편집 Store 팩토리. roomFormReducer 는 의존이 없어 그대로 조립한다(RoomCreationUI 는 UI 전용).
    ///
    /// 색은 hex 로 들고 있으므로 피커 인덱스로 바꿔 넘긴다. 팔레트 밖의 색이면 `nil` — 화면이
    /// my-room 썸네일로 열리고 사용자가 다시 고르면 된다(잘못된 칸을 켜는 것보다 낫다).
    func makeRoomFormStore() -> RoomFormStore {
        let store = RoomFormStore(
            RoomFormState(
                mode: .edit,
                roomName: editingRoom?.title ?? "",
                roomDescription: editingRoom?.memo ?? "",
                selectedColorIndex: editingRoom.flatMap { RoomColorPalette.index(ofHex: $0.color) }
            ),
            reduce: roomFormReducer()
        )
        store.observeNavigation { [weak self] in self?.handle($0) }
        return store
    }

    func handle(_ nav: RoomFormNav) {
        switch nav {
        case .didSubmit, .didCancel, .didSkip:
            // 편집 완료/취소 후 방 상세로 복귀. (실제 방 편집 로직은 후속 — 현재 RoomCreationUI 는 UI 전용)
            if !path.isEmpty { path.removeLast() }
        }
    }
}
