import Domain

/// 앱 진입 분기가 요구하는 좁은 의존성 묶음.
///
/// Composition Root(App)의 `AppDependencies` 가 이 프로토콜을 준수한다.
/// reduce 는 Repository 가 아니라 **UseCase** 만 받는다(Clean Architecture 규칙).
public protocol LaunchDeps {
    var ensureSession: EnsureSessionUseCase { get }
    /// 온보딩을 마쳤는지 묻는 창구. 프로필이 있으면 등록된 것이다 —
    /// 이 판단만을 위한 별도 UseCase 를 두지 않고 조회 하나로 겸한다.
    var fetchProfile: FetchProfileUseCase { get }
}
