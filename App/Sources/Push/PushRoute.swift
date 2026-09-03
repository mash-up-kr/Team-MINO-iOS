import Foundation

/// 푸시를 눌렀을 때 갈 곳.
///
/// **지금은 한 가지뿐이다.** 서버가 payload 에 무엇을 싣는지 계약이 정해지지 않아 상세 화면으로 갈
/// 근거가 없다. 추측한 키를 미리 파싱해 두면 계약이 확정되는 날 조용히 어긋난 채로 남는다.
///
/// 계약이 오면 ① 여기 case 를 늘리고 ② ``init(userInfo:)`` 를 채우면 끝이다 —
/// 소비자(`AppCoordinator.open(push:)`)가 switch 라 새 case 를 빠뜨리면 컴파일이 깨진다.
/// (알림 목록의 `type` → 목적지 매핑은 `Data/DTO/NotificationDTO.swift` 의 `mapDestination` 에 있다.
///  payload 가 같은 어휘로 오면 그 매핑을 재사용할 수 있는지부터 본다.)
enum PushRoute: Equatable, Sendable {
    case notificationTab

    init(userInfo: [AnyHashable: Any]) {
        self = .notificationTab
    }
}
