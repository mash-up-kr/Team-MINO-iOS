import Domain
import PlaceDetailUI
import RoomShareUI

/// HomeCoordinator 가 요구하는 좁은 의존성 묶음.
///
/// 장소 상세(``PlaceDetailDeps``)를 확장한다 — 홈 카드를 누르면 그 화면으로 가기 때문이다
/// (Figma 002-1-1). 조립부(App)는 지금처럼 `HomeDeps` 하나만 준수하면 된다.
public protocol HomeDeps: PlaceDetailDeps, RoomShareCreateRoomDeps {
    var fetchRooms: FetchRoomsUseCase { get }
    /// 홈 카드 덱 — 서버가 조회 기준으로 골라 준 한 덱. 가까운순의 기준점(`currentLocation`)은
    /// 장소 상세와 같은 것을 쓴다(``PlaceDetailDeps`` 가 이미 요구한다).
    var fetchHomeCards: FetchHomeCardsUseCase { get }
    var lastViewedRoom: LastViewedRoomUseCase { get }
    var homeGuide: HomeGuideUseCase { get }
    var savePin: SavePinToRoomsUseCase { get }
    /// 「다른 방에 공유」 시트(011-1)가 고를 수 있는 방 목록. 저장 탭과 같은 UseCase 다.
    var fetchShareTargets: FetchShareTargetsUseCase { get }
    var createRoom: CreateRoomUseCase { get }
}
