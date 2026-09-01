import Domain

/// 알림 탭 flow 가 쓰는 의존만 담는다(ISP).
public protocol NotificationDeps {
    var fetchNotifications: FetchNotificationsUseCase { get }
    /// 장소 알림의 이동 대상 조회. `payload.placeId` 는 핀 id 와 같은 값이라 그대로 넣는다.
    var fetchPinDetail: FetchPinDetailUseCase { get }
    /// 방 알림의 이동 대상 조회이자, 장소 알림이 배경 지도를 세우는 데 쓰는 방 컨텍스트.
    var fetchRoom: FetchRoomUseCase { get }
}
