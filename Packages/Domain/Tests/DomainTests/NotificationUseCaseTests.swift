import Foundation
import Testing
@testable import Domain

/// 유스케이스가 저장소로 **무엇을 어떻게 넘기는지**만 본다. 조회 결과의 내용은 Data 테스트 몫이다.
/// 오버로드가 둘이라 첫 장 호출이 다음 장 메서드로 새는 실수가 컴파일로는 안 잡힌다 — 그 자리를 막는다.
///
/// spy 저장소는 호출을 기록해야 하므로 가변 상태를 갖는다. `NotificationRepository` 가 `Sendable` 이고
/// Domain 이 Swift 6 모드라 **spy 도 `actor` 여야 한다** — 불변 `let` 만 가진 기존
/// `StubMemberRepository`(`FetchMemberUseCaseTests`)를 그대로 복사하면 컴파일이 막힌다.
@Suite("알림 유스케이스 위임")
struct NotificationUseCaseTests {
    @Test("첫 장 조회는 크기 없는 저장소 메서드로 간다")
    func firstPageGoesToSizelessRepositoryMethod() async throws {
        let spy = SpyNotificationRepository()
        let sut = DefaultFetchNotificationsUseCase(repository: spy)

        _ = try await sut.execute()

        #expect(await spy.calledFirstPage)
        #expect(await spy.calledNextPageRequest == nil)
    }

    @Test("다음 장 조회는 받은 요청을 그대로 넘긴다")
    func nextPagePassesRequestUnchanged() async throws {
        let spy = SpyNotificationRepository()
        let sut = DefaultFetchNotificationsUseCase(repository: spy)
        let request = PageRequest(page: 2, pageSize: 20)

        _ = try await sut.execute(next: request)

        #expect(await spy.calledNextPageRequest == request)
        #expect(await spy.calledFirstPage == false)
    }
}

private actor SpyNotificationRepository: NotificationRepository {
    private(set) var calledFirstPage = false
    private(set) var calledNextPageRequest: PageRequest?

    func notifications() async throws -> Page<AppNotification> {
        calledFirstPage = true
        return Page(items: [], page: 0, pageSize: 20, hasNext: false)
    }

    func notifications(_ request: PageRequest) async throws -> Page<AppNotification> {
        calledNextPageRequest = request
        return Page(items: [], page: request.page, pageSize: request.pageSize, hasNext: false)
    }
}
