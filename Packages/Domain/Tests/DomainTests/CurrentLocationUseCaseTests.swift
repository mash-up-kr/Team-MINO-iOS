import Foundation
import Testing
@testable import Domain

// MARK: - Test Doubles

/// OS 위치 권한을 흉내 낸다. 알림 쪽은 이 유스케이스가 보지 않아 기본값으로 둔다.
private final class FakeLocationPermissions: PermissionRepository, @unchecked Sendable {
    var status: PermissionStatus
    /// 시스템 팝업에 사용자가 무엇을 답했는지 — 요청 뒤 상태.
    var statusAfterRequest: PermissionStatus?
    private(set) var didRequest = false

    init(status: PermissionStatus) { self.status = status }

    func notificationStatus() async -> PermissionStatus { .notDetermined }
    func requestNotification() async -> PermissionStatus { .notDetermined }

    func locationStatus() async -> PermissionStatus { status }

    func requestLocation() async -> PermissionStatus {
        didRequest = true
        status = statusAfterRequest ?? status
        return status
    }
}

private final class FakeCurrentLocation: CurrentLocationRepository, @unchecked Sendable {
    var coordinate: Coordinate?
    private(set) var didMeasure = false

    init(coordinate: Coordinate?) { self.coordinate = coordinate }

    func currentCoordinate() async -> Coordinate? {
        didMeasure = true
        return coordinate
    }
}

// MARK: -

struct CurrentLocationUseCaseTests {
    private let seongsu = Coordinate(latitude: 37.5443, longitude: 127.0557)

    private func make(
        permissions: FakeLocationPermissions,
        location: FakeCurrentLocation
    ) -> DefaultCurrentLocationUseCase {
        DefaultCurrentLocationUseCase(permissions: permissions, location: location)
    }

    @Test("허용된 상태면 묻지 않고 좌표를 낸다")
    func granted() async {
        let permissions = FakeLocationPermissions(status: .granted)
        let location = FakeCurrentLocation(coordinate: seongsu)

        #expect(await make(permissions: permissions, location: location).execute() == .coordinate(seongsu))
        #expect(permissions.didRequest == false)
    }

    @Test("미결정이면 그 자리에서 묻고, 허용되면 좌표를 낸다")
    func notDetermined_thenGranted() async {
        let permissions = FakeLocationPermissions(status: .notDetermined)
        permissions.statusAfterRequest = .granted
        let location = FakeCurrentLocation(coordinate: seongsu)

        #expect(await make(permissions: permissions, location: location).execute() == .coordinate(seongsu))
        #expect(permissions.didRequest)
    }

    @Test("팝업에서 거부하면 permissionDenied — 측위는 시도하지 않는다")
    func notDetermined_thenDenied() async {
        let permissions = FakeLocationPermissions(status: .notDetermined)
        permissions.statusAfterRequest = .denied
        let location = FakeCurrentLocation(coordinate: seongsu)

        #expect(await make(permissions: permissions, location: location).execute() == .permissionDenied)
        #expect(location.didMeasure == false)
    }

    @Test("이미 거부된 상태면 팝업이 다시 뜨지 않으므로 묻지 않는다")
    func denied() async {
        let permissions = FakeLocationPermissions(status: .denied)
        let location = FakeCurrentLocation(coordinate: seongsu)

        #expect(await make(permissions: permissions, location: location).execute() == .permissionDenied)
        #expect(permissions.didRequest == false)
        #expect(location.didMeasure == false)
    }

    @Test("권한은 있는데 측위에 실패하면 unavailable — 권한 거부와 구분한다")
    func unavailable() async {
        let permissions = FakeLocationPermissions(status: .granted)
        let location = FakeCurrentLocation(coordinate: nil)

        #expect(await make(permissions: permissions, location: location).execute() == .unavailable)
        #expect(location.didMeasure)
    }
}
