import Domain
import Foundation

/// 토큰 업로드를 **두드리는** 자리.
///
/// 정책(켜짐 판정·중복 제거·실패 처리)은 Domain 의 `SyncPushTokenUseCase` 에 있고 여기는 "언제
/// 두드리나"만 안다 — App 타깃엔 테스트 타깃이 없어, 여기 로직을 넣으면 어떤 오라클에도 걸리지 않는다.
@MainActor
final class PushTokenSync {
    private let useCase: SyncPushTokenUseCase

    init(useCase: SyncPushTokenUseCase) {
        self.useCase = useCase
    }

    /// **기다리지 않는다.** 부르는 곳이 전부 사용자 조작 경로(스위치·앱 진입·포그라운드 복귀)라
    /// 네트워크를 기다리면 그만큼 화면이 굳는다.
    func kick() {
        Task { await useCase.execute() }
    }

    func tokenDidRefresh(_ token: String) {
        Task { await useCase.execute(token: token) }
    }
}
