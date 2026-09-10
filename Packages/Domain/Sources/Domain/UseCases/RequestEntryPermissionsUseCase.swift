/// 저장 탭 최초 진입에서 묻는 권한 묶음.
///
/// 위치를 묻고, **그 시스템 팝업이 실제로 떴을 때만** 이어서 알림도 묻는다.
///
/// 조건을 단 이유는 진입 경로가 두 종류의 사용자를 함께 밟기 때문이다.
///
/// | | 위치 팝업 | 알림을 어디서 묻나 |
/// |---|---|---|
/// | 새로 설치한 사용자 | 뜬다(미결정) | **여기서 이어서** — 앞 팝업이 맥락이 된다 |
/// | 업데이트한 사용자 | 안 뜬다(이미 결정됨) | 지금까지처럼 마이페이지 스위치를 누를 때 |
///
/// 조건 없이 물으면 업데이트 사용자에게는 늘 보던 지도 위로 시스템 팝업 하나가 맥락 없이 뜬다.
/// 그리고 거기서 거부되면 **스위치를 눌러도 영영 다시 못 묻는다** — iOS 알림 팝업은 설치당 한 번뿐이라,
/// 맥락 없이 태워 버리면 스위치가 켜지지 않는 채로 남는다.
public protocol RequestEntryPermissionsUseCase: Sendable {
    /// - Returns: 위치 조회 결과. 알림 요청 여부는 화면이 알 필요가 없어 싣지 않는다.
    func execute() async -> CurrentLocationResult
}

public struct DefaultRequestEntryPermissionsUseCase: RequestEntryPermissionsUseCase {
    private let permissions: PermissionRepository
    private let currentLocation: CurrentLocationUseCase
    private let requestNotification: RequestNotificationPermissionUseCase

    public init(
        permissions: PermissionRepository,
        currentLocation: CurrentLocationUseCase,
        requestNotification: RequestNotificationPermissionUseCase
    ) {
        self.permissions = permissions
        self.currentLocation = currentLocation
        self.requestNotification = requestNotification
    }

    public func execute() async -> CurrentLocationResult {
        // 묻기 **전에** 봐야 한다 — `currentLocation` 이 팝업을 띄우고 나면 상태가 이미 바뀌어 있다.
        let locationWillPrompt = await permissions.locationStatus() == .notDetermined
        let result = await currentLocation.execute()
        // 위치를 거부했어도 잇는다. 팝업이 떴다는 건 이 사용자가 지금 권한을 정하는 중이라는 뜻이고,
        // 둘은 서로 다른 기능이라 한쪽 거부가 다른 쪽을 묻지 않을 이유가 되지 않는다.
        if locationWillPrompt { await requestNotification.execute() }
        return result
    }
}
