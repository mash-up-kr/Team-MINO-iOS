/// 알림 목록을 한 장씩 조회한다.
/// 하나의 비즈니스 유스케이스 = 하나의 UseCase. UI 관심사(화면 상태, 네비게이션)를 포함하지 않는다.
/// [Convention] .claude/docs/mvi-coordinator-di.md — reduce 는 Repository 가 아니라 UseCase 를 받는다
public protocol FetchNotificationsUseCase: Sendable {
    /// 첫 장. 페이지 크기는 구현체가 정한다.
    func execute() async throws -> Page<AppNotification>
    /// 다음 장. `Page.next` 의 결과를 그대로 넘긴다.
    func execute(next request: PageRequest) async throws -> Page<AppNotification>
}

public struct DefaultFetchNotificationsUseCase: FetchNotificationsUseCase {
    private let repository: NotificationRepository

    public init(repository: NotificationRepository) {
        self.repository = repository
    }

    public func execute() async throws -> Page<AppNotification> {
        try await repository.notifications()
    }

    public func execute(next request: PageRequest) async throws -> Page<AppNotification> {
        try await repository.notifications(request)
    }
}
