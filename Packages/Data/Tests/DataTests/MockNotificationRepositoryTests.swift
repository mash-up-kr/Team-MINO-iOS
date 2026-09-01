import Foundation
import Testing
import Domain
@testable import Data

/// 가짜 저장소가 **실제 경계 매핑을 타는지**와 페이지 진행이 이어지는지를 본다.
/// 네트워크 구현으로 갈아끼울 때 매핑 계층이 그대로 재사용된다는 전제가 여기서 성립한다.
@Suite("MockNotificationRepository 페이지 진행")
struct MockNotificationRepositoryTests {
    @Test("첫 장은 서버 기본 크기만큼 담고 다음 장이 있다고 알린다")
    func firstPageUsesDefaultSizeAndHasNext() async throws {
        let sut = MockNotificationRepository()

        let page = try await sut.notifications()

        #expect(page.items.count == PageRequest.defaultPageSize)
        #expect(page.hasNext)
    }

    @Test("첫 장이 유형 6종과 알 수 없는 유형을 실제로 흡수해 담는다")
    func firstPageCarriesRealTypesNotJustCount() async throws {
        // 개수·hasNext·정렬만 보면, mapType 의 문자열 대응표가 mockJSON 의 type 값과 어긋나도
        // (예: 계약 확정으로 switch 문자열만 바뀌고 목은 안 바뀐 경우) 21건이 전부 .unknown 으로
        // 무너져도 이 스위트가 못 잡는다. 유형별 대표값을 직접 확인해 그 붕괴를 여기서 막는다.
        let sut = MockNotificationRepository()

        let page = try await sut.notifications()
        let types = page.items.map(\.type)

        #expect(types.contains(.duplicateSave))
        #expect(types.contains(.saveError))
        #expect(types.contains(.nearbyReminder))
        #expect(types.contains(.commentReminder))
        #expect(types.contains(.memberJoined))
        #expect(types.contains(.roomJoined))
        #expect(page.items.contains { if case .unknown = $0.type { true } else { false } })

        // FR-012 의 썸네일 두 갈래(사진 / 기본 아이콘)가 실제로 목에서 재현되는지 —
        // thumbnailUrl 을 통째로 빼도 이 단언 없이는 개수·유형 단언 어느 것도 안 잡는다.
        #expect(page.items.contains { $0.thumbnailURL != nil })
        #expect(page.items.contains { $0.thumbnailURL == nil })

        // 도착지 세 갈래가 목에 다 있어야 화면 확인이 의미를 갖는다.
        let destinations = page.items.map(\.destination)
        #expect(destinations.contains { if case .place = $0 { true } else { false } })
        #expect(destinations.contains { if case .room = $0 { true } else { false } })
        #expect(destinations.contains(.saveError))
    }

    @Test("다음 장은 이전 장과 항목이 겹치지 않는다")
    func nextPageDoesNotRepeatItems() async throws {
        let sut = MockNotificationRepository()

        let firstPage = try await sut.notifications()
        let nextRequest = try #require(firstPage.next)
        let secondPage = try await sut.notifications(nextRequest)

        let firstIDs = Set(firstPage.items.map(\.id))
        let secondIDs = Set(secondPage.items.map(\.id))
        #expect(firstIDs.isDisjoint(with: secondIDs))
    }

    @Test("마지막 장에는 다음 요청이 없다")
    func lastPageHasNoNextRequest() async throws {
        let sut = MockNotificationRepository()

        let firstPage = try await sut.notifications()
        let nextRequest = try #require(firstPage.next)
        let lastPage = try await sut.notifications(nextRequest)

        #expect(lastPage.hasNext == false)
        #expect(lastPage.next == nil)
    }

    @Test("항목이 없으면 빈 장을 돌려준다")
    func returnsEmptyPageWhenNoItems() async throws {
        let sut = MockNotificationRepository(json: MockNotificationRepository.emptyJSON)

        let page = try await sut.notifications()

        #expect(page.items.isEmpty)
        #expect(page.hasNext == false)
    }

    @Test("첫 장은 최신순이다")
    func firstPageIsSortedByCreatedAtDescending() async throws {
        let sut = MockNotificationRepository()

        let page = try await sut.notifications()

        // `sorted(by: >)` 와 비교하면 안정 정렬을 보장 안 하는 Swift `sorted` 특성상 동시각 항목이
        // 섞여도 실패할 수 있다 — "내림차순(비증가)" 이라는 의도 그대로 인접 쌍만 비교한다.
        let dates = page.items.map(\.createdAt)
        #expect(zip(dates, dates.dropFirst()).allSatisfy { $0 >= $1 })
    }

    @Test("잘못된 page 는 크래시 대신 저장소 오류로 실패한다")
    func invalidPageFailsWithDomainErrorInsteadOfCrashing() async throws {
        // 음수는 Array 음수 인덱스 트랩, `page: Int.max, pageSize: 20` 는 곱셈(page*pageSize)
        // 오버플로 트랩으로 이어지는 경로다 — 둘 다 do/catch 밖에서 일어나 가드가 없으면
        // 프로세스가 죽는다(수정 전 실측 확인).
        let sut = MockNotificationRepository()

        await #expect(throws: DomainError.notificationsFetchFailed) {
            _ = try await sut.notifications(PageRequest(page: -1, pageSize: 20))
        }
        await #expect(throws: DomainError.notificationsFetchFailed) {
            _ = try await sut.notifications(PageRequest(page: Int.max, pageSize: 20))
        }
    }

    @Test("곱셈은 안 넘쳐도 그 결과에 pageSize 를 더하면 넘치는 경계도 막는다")
    func invalidPageFailsOnAdditionOverflowEvenWhenMultiplicationDoesNot() async throws {
        // page: Int.max, pageSize: 1 → start = Int.max*1 = Int.max (곱셈은 안 넘친다) →
        // start + pageSize = Int.max + 1 (덧셈에서 넘친다). 곱셈만 막고 덧셈을 안 막으면
        // 이 조합이 정확히 그 틈을 통과해 크래시한다(code-review 재검에서 발견).
        let sut = MockNotificationRepository()

        await #expect(throws: DomainError.notificationsFetchFailed) {
            _ = try await sut.notifications(PageRequest(page: Int.max, pageSize: 1))
        }
    }
}
