import Foundation

/// OS 권한을 조회·요청하는 추상 인터페이스. **OS 가 단일 진실 공급원이라 캐시하지 않는다**(FR-009).
public protocol PermissionRepository: Sendable {
    func notificationStatus() async -> PermissionStatus
    /// 시스템 팝업을 띄우고 응답 뒤의 상태를 돌려준다. `notDetermined` 가 아닐 때 부르면 팝업 없이 현재 상태만 돌아온다.
    func requestNotification() async -> PermissionStatus
    func locationStatus() async -> PermissionStatus
    func requestLocation() async -> PermissionStatus
}
