import CoreLocation
import Domain
import UserNotifications

/// `PermissionRepository` 의 iOS 구현. **조회는 매번 OS 에 다시 묻는다** — OS 가 단일 진실
/// 공급원이라 캐시하면 설정 앱에서 바꾼 값과 어긋난다(FR-009).
///
/// 구현이 Data 가 아니라 App 에 있는 건 `FirebaseAuthRepository` 와 같은 이유다 —
/// 플랫폼 프레임워크 어댑터는 컴포지션 루트가 갖는다.
@MainActor
final class SystemPermissionRepository: NSObject, PermissionRepository {
    private let center = UNUserNotificationCenter.current()
    private let locationManager = CLLocationManager()
    /// 위치 권한 요청은 콜백(delegate)으로 결과가 오므로 async 로 바꿔 이어 붙인다.
    private var pendingLocationRequest: CheckedContinuation<PermissionStatus, Never>?

    override init() {
        super.init()
        locationManager.delegate = self
    }

    // MARK: - 알림

    func notificationStatus() async -> PermissionStatus {
        await center.notificationSettings().authorizationStatus.permissionStatus
    }

    func requestNotification() async -> PermissionStatus {
        // 이미 결정된 뒤에 부르면 시스템은 팝업 없이 곧장 현재 값을 돌려준다 — 굳이 막지 않는다.
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return await notificationStatus()
    }

    // MARK: - 위치

    func locationStatus() async -> PermissionStatus {
        locationManager.authorizationStatus.permissionStatus
    }

    func requestLocation() async -> PermissionStatus {
        let status = locationManager.authorizationStatus
        guard status == .notDetermined else { return status.permissionStatus }

        // 기기 전체 위치 서비스가 꺼져 있으면 `requestWhenInUseAuthorization` 은 앱 권한을 바꾸지
        // 않는다 — 시스템이 "위치 서비스를 켤까요?" 를 대신 띄우고, 거절하면 앱 권한은 미결정 그대로다.
        // 그러면 아래 delegate 가 영원히 오지 않아 호출자가 매달린다. 요청 전에 걸러 낸다.
        // (blocking 호출이라 메인에서 부르지 않는다 — Apple 문서 지침)
        guard await Task.detached(priority: .userInitiated, operation: {
            CLLocationManager.locationServicesEnabled()
        }).value else {
            return .denied
        }

        // 요청이 겹치면 앞선 대기를 풀어 준다 — 재개되지 않은 continuation 은 누수다.
        // 여기까지 온 이상 상태는 위 가드로 미결정이 확정이라 `.notDetermined` 로 돌려보낸다.
        pendingLocationRequest?.resume(returning: .notDetermined)
        pendingLocationRequest = nil

        // 취소되면(화면 이탈 등) 대기를 직접 풀어 준다. `withCheckedContinuation` 은 취소에
        // 반응하지 않아서, 이게 없으면 Task 가 깨어나지 못한 채 남는다. 게다가 이 저장소는
        // 앱 수명이라 continuation 이 해제되지 않아 누수 경고조차 뜨지 않는다.
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                pendingLocationRequest = continuation
                locationManager.requestWhenInUseAuthorization()
            }
        } onCancel: {
            Task { @MainActor in self.resumePendingLocationRequest(with: .notDetermined) }
        }
    }

    /// 대기 중인 위치 권한 요청을 한 번만 풀어 준다. 중복 resume 은 크래시라 nil 로 비운 뒤 재개한다.
    private func resumePendingLocationRequest(with status: PermissionStatus) {
        guard let continuation = pendingLocationRequest else { return }
        pendingLocationRequest = nil
        continuation.resume(returning: status)
    }
}

extension SystemPermissionRepository: CLLocationManagerDelegate {
    // CLLocationManager 를 메인에서 만들었으므로 이 콜백도 메인으로 온다.
    // manager 는 Sendable 이 아니라 클로저로 넘기지 않고, 필요한 값(Sendable 한 상태)만 꺼내 옮긴다.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let rawStatus = manager.authorizationStatus
        MainActor.assumeIsolated {
            // delegate 를 붙이는 순간에도 한 번 불린다. 아직 미결정이면 사용자가 고르기 전이라 기다린다.
            guard rawStatus != .notDetermined else { return }
            resumePendingLocationRequest(with: rawStatus.permissionStatus)
        }
    }
}

private extension UNAuthorizationStatus {
    /// `provisional`·`ephemeral` 은 알림을 실제로 받는 상태라 허용으로 본다.
    var permissionStatus: PermissionStatus {
        switch self {
        case .notDetermined: .notDetermined
        case .authorized, .provisional, .ephemeral: .granted
        case .denied: .denied
        @unknown default: .denied
        }
    }
}

private extension CLAuthorizationStatus {
    /// `restricted`(기기 정책으로 막힘)는 앱이 켤 수 없다는 점에서 `denied` 와 같다.
    var permissionStatus: PermissionStatus {
        switch self {
        case .notDetermined: .notDetermined
        case .authorizedWhenInUse, .authorizedAlways: .granted
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }
}
