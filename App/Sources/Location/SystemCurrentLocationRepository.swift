import CoreLocation
import Domain

/// `CurrentLocationRepository` 의 iOS 구현. `requestLocation()` 으로 **한 번만** 측위한다
/// (연속 갱신이 아니라 1회 fix — 다 받으면 시스템이 알아서 멈춘다).
///
/// 구현이 Data 가 아니라 App 에 있는 건 `SystemPermissionRepository` 와 같은 이유다 —
/// 플랫폼 프레임워크 어댑터는 컴포지션 루트가 갖는다.
///
/// ## 왜 `SystemPermissionRepository` 와 `CLLocationManager` 를 공유하지 않는가
/// 저쪽은 인가 변경 delegate 콜백에 continuation 하나를 이미 물려 두고 있다. 여기에 측위
/// 콜백까지 얹으면 한 delegate 가 성격이 다른 두 콜백과 두 continuation 을 동시에 관리하게 되어,
/// "인가 대기 중에 측위 결과가 먼저 온" 같은 조합마다 누가 어느 대기를 풀지 따져야 한다.
/// 수명도 다르다 — 권한 저장소는 앱 내내 살고 측위는 호출마다 시작해서 끝난다.
/// `CLLocationManager` 는 여러 개 만들어도 되고(권한은 앱 단위) 만드는 비용도 없다.
@MainActor
final class SystemCurrentLocationRepository: NSObject, CurrentLocationRepository {
    private let manager = CLLocationManager()
    private var pendingRequest: CheckedContinuation<Coordinate?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        // 3km 반경을 가르는 데는 100m 정확도로 충분하다. 기본값(Best)은 fix 를 오래 기다리고
        // 배터리를 더 쓴다 — 정렬 한 번 하자고 치를 값이 아니다.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// 권한 확인은 호출자(`DefaultCurrentLocationUseCase`)가 이미 끝냈다는 전제다.
    /// 그래도 권한이 없으면 시스템이 delegate 로 오류를 돌려주므로 nil 로 떨어진다.
    func currentCoordinate() async -> Coordinate? {
        // 앞선 요청이 남아 있으면 먼저 풀어 준다 — 재개되지 않은 continuation 은 누수다.
        resumePendingRequest(with: nil)

        // 취소되면(화면 이탈 등) 대기를 직접 풀어 준다. `withCheckedContinuation` 은 취소에
        // 반응하지 않아서, 이게 없으면 Task 가 깨어나지 못한 채 남는다.
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                pendingRequest = continuation
                manager.requestLocation()
            }
        } onCancel: {
            Task { @MainActor in self.resumePendingRequest(with: nil) }
        }
    }

    /// 대기 중인 측위 요청을 한 번만 풀어 준다. 중복 resume 은 크래시라 nil 로 비운 뒤 재개한다.
    private func resumePendingRequest(with coordinate: Coordinate?) {
        guard let continuation = pendingRequest else { return }
        pendingRequest = nil
        continuation.resume(returning: coordinate)
    }
}

extension SystemCurrentLocationRepository: CLLocationManagerDelegate {
    // CLLocationManager 를 메인에서 만들었으므로 이 콜백도 메인으로 온다.
    // manager·CLLocation 은 Sendable 이 아니라 그대로 넘기지 않고, 필요한 값만 꺼내 옮긴다.
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last.map {
            Coordinate(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
        }
        MainActor.assumeIsolated {
            resumePendingRequest(with: coordinate)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 측위 실패는 도메인에 "이번엔 못 얻었다"(nil)로만 전한다 — CLError 세부는 화면이 쓸 데가 없다.
        MainActor.assumeIsolated {
            resumePendingRequest(with: nil)
        }
    }
}
