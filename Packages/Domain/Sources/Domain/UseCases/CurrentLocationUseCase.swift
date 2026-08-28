import Foundation

/// 현재 위치 조회의 결과.
///
/// `Coordinate?` 하나로 합치지 않는다 — **"권한이 없어 앞으로도 못 얻는다" 와 "이번에 못 얻었다" 는
/// 화면이 해야 할 일이 정반대다.** 전자는 재시도가 무의미해 OS 설정 앱으로 보내야 하고(EC-003),
/// 후자는 재시도가 의미 있다. 도메인이 ``PermissionStatus`` 로 이미 들고 있는 구분이라
/// 여기서만 nil 로 뭉개면 상위가 되살릴 수 없는 정보 손실이 된다.
public enum CurrentLocationResult: Equatable, Sendable {
    case coordinate(Coordinate)
    /// 위치 권한이 없다. iOS 는 한 번 거부되면 시스템 팝업이 다시 뜨지 않는다(``PermissionStatus`` 주석).
    case permissionDenied
    /// 권한은 있는데 측위에 실패했다.
    case unavailable
}

/// "지금 내 위치" 를 얻는 유스케이스.
///
/// 권한이 아직 미결정이면 **그 자리에서 묻는다** — 위치가 필요해진 순간(거리순을 고른 순간)이
/// 곧 요청 맥락이라 사용자에게 이유가 분명하다. 이미 거부된 상태라면 팝업이 뜨지 않으므로
/// 묻지 않고 ``CurrentLocationResult/permissionDenied`` 로 돌아온다.
public protocol CurrentLocationUseCase: Sendable {
    func execute() async -> CurrentLocationResult
}

public struct DefaultCurrentLocationUseCase: CurrentLocationUseCase {
    private let permissions: PermissionRepository
    private let location: CurrentLocationRepository

    public init(permissions: PermissionRepository, location: CurrentLocationRepository) {
        self.permissions = permissions
        self.location = location
    }

    public func execute() async -> CurrentLocationResult {
        var status = await permissions.locationStatus()
        if status == .notDetermined {
            status = await permissions.requestLocation()
        }
        guard status == .granted else { return .permissionDenied }
        guard let coordinate = await location.currentCoordinate() else { return .unavailable }
        return .coordinate(coordinate)
    }
}
