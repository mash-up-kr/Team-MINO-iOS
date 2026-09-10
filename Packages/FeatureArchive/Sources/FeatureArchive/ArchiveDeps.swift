import Core
import Domain
import PlaceDetailUI
import RoomShareUI

/// ArchiveCoordinator 가 요구하는 좁은 의존성 묶음.
///
/// Composition Root(App)의 `AppDependencies` 가 이 프로토콜을 준수하고,
/// Coordinator 는 자신의 deps 프로토콜만 알면 되므로 결합이 최소화된다.
/// reduce 는 Repository 가 아니라 **UseCase** 만 받는다(Clean Architecture 규칙).
///
/// 자식 flow·공용 화면의 좁은 의존(``RoomShareCreateRoomDeps``·``PlaceDetailDeps``)을 확장한다 —
/// 자식은 그 좁은 창만 보고, 조립부(App)는 지금처럼 `ArchiveDeps` 하나만 준수하면 된다.
public protocol ArchiveDeps: RoomShareCreateRoomDeps, PlaceDetailDeps {
    var fetchRooms: FetchRoomsUseCase { get }
    /// 방 상세 케밥 → 방 편집(004-5). 생성(`createRoom`)은 자식 flow 의 좁은 창
    /// (``RoomShareCreateRoomDeps``)에 있고, 편집은 이 flow 만 쓴다.
    var updateRoom: UpdateRoomUseCase { get }
    /// 저장된 장소 목록 — 방 상세와 방 리스트 탭 지도가 함께 쓴다. **정렬·필터는 서버가 한다.**
    var fetchRoomPins: FetchRoomPinsUseCase { get }
    /// 다른 방에 공유 시트가 그릴 방 목록 — 각 방에 이 장소가 이미 있는지까지 함께.
    var fetchShareTargets: FetchShareTargetsUseCase { get }
    /// 다른 방에 공유 — 고른 방들에 이 장소를 담는다.
    var savePin: SavePinToRoomsUseCase { get }
    /// 장소 카드 케밥의 "장소 삭제"(004-1 ⑧) — 확인 다이얼로그를 거친 뒤 이 방에서 지운다.
    var deletePin: DeletePinUseCase { get }
    /// 방 상세 거리순 정렬(004-1 ⑥) 의 기준점 — "내 기준 3km" 를 재려면 내 위치가 있어야 한다.
    var currentLocation: CurrentLocationUseCase { get }
    /// 저장 탭 최초 진입의 권한 묶음 — 위치를 묻고, 그 팝업이 실제로 뜬 경우에만 알림도 잇는다.
    /// 업데이트 사용자(위치가 이미 결정됨)는 여기가 아니라 마이페이지 진입에서 묻는다.
    var entryPermissions: RequestEntryPermissionsUseCase { get }
    /// 공동방 생성 유도 시트를 "나중에 만들래요" 로 미뤄 둔 상태(2주). 서버가 모르는 기기 로컬
    /// 표시 정책이라 UseCase 가 아니라 ``SnoozeSwitch`` 를 그대로 받는다.
    var roomCreationPromptSnooze: SnoozeSwitch { get }
    /// 방 상세 헤더 `+` → 친구 초대 시트(004-4-2)가 발급받는 초대 코드.
    var fetchInviteCode: FetchInviteCodeUseCase { get }
    /// 초대 링크의 스킴·호스트. **서버는 코드만 준다** — 링크 조립은 클라이언트 몫이라 읽기
    /// (`DeeplinkParser`)와 같은 설정을 써서 "우리가 만든 링크를 우리가 못 읽는" 상태를 막는다.
    var deeplink: DeeplinkConfiguration { get }
}
