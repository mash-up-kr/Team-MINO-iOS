import Foundation

/// 마이페이지 `위치 설정` 스위치의 비즈니스 규칙.
///
/// 알림과 달리 앱 자체 플래그가 없다 — 표시값이 곧 OS 위치 권한 상태다(spec §2.3).
/// 끄기에 해당하는 메서드가 없는 것도 같은 이유다: 앱은 이미 받은 권한을 스스로 취소할 수 없어
/// OS 설정 앱으로 보내는 것 외에 할 수 있는 일이 없다(FR-015) — 그건 화면의 몫이다.
public protocol LocationSettingUseCase: Sendable {
    func isOn() async -> Bool
    func turnOn() async -> PermissionActivation
}

public struct DefaultLocationSettingUseCase: LocationSettingUseCase {
    private let permissions: PermissionRepository

    public init(permissions: PermissionRepository) {
        self.permissions = permissions
    }

    public func isOn() async -> Bool {
        await permissions.locationStatus() == .granted
    }

    public func turnOn() async -> PermissionActivation {
        let status = await permissions.locationStatus()
        guard status == .notDetermined else {
            return status == .granted ? .activated : .needsSystemSettings
        }
        return await permissions.requestLocation() == .granted ? .activated : .rejected
    }
}
