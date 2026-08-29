import Domain
import PlaceDetailUI

/// HomeCoordinator 가 요구하는 좁은 의존성 묶음.
///
/// 장소 상세(``PlaceDetailDeps``)를 확장한다 — 홈 카드를 누르면 그 화면으로 가기 때문이다
/// (Figma 002-1-1). 조립부(App)는 지금처럼 `HomeDeps` 하나만 준수하면 된다.
public protocol HomeDeps: PlaceDetailDeps {
    var fetchRooms: FetchRoomsUseCase { get }
    var fetchPins: FetchPinsUseCase { get }
    var lastViewedRoom: LastViewedRoomUseCase { get }
    var homeGuide: HomeGuideUseCase { get }
    var savePin: SavePinToRoomsUseCase { get }
    var createRoom: CreateRoomUseCase { get }
    /// 홈 우상단 마스코트의 소품을 정하는 내 아바타 색 (Figma `character/Home_Avatar`).
    var fetchProfile: FetchProfileUseCase { get }
}
