import Foundation

/// OS 권한 상태. iOS 는 한 번 거부되면 재요청해도 시스템 팝업이 다시 뜨지 않아
/// **`denied` 가 곧 "앱에서는 더 못 켬"** 이다(Android 처럼 요청 이력을 따로 기록할 필요가 없다).
public enum PermissionStatus: Equatable, Sendable {
    /// 아직 묻지 않았다 — 시스템 팝업을 띄울 수 있다.
    case notDetermined
    case granted
    /// 거부됐다. 켜려면 OS 설정 앱으로 보내야 한다(EC-003).
    case denied
}
