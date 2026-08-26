/// 목록 API 의 한 페이지. 알림·방·핀 등 어떤 항목 타입에도 쓰이는 공용 값 타입이다.
/// [Convention] .claude/docs/clean-architecture.md — Value Object: 값으로 동등성 비교, let 불변, 프레임워크 비의존
///
/// 한 장만 표현한다. 여러 장을 이어 붙이는 누적·중복 제거·재진입 방어는 소비자(화면 상태) 몫이다.
public struct Page<Item> {
    public let items: [Item]
    /// 0-based. 서버가 `page` 요청 파라미터를 "0부터 시작" 으로 정의한다.
    public let page: Int
    /// **요청한** 페이지 크기다. 서버 응답의 같은 이름 필드를 그대로 옮기지 않는다 — 그 필드는
    /// 이번 장에 실제 담긴 개수일 수 있어서, 되먹이면 다음 장 오프셋이 어긋난다.
    public let pageSize: Int
    public let hasNext: Bool

    public init(items: [Item], page: Int, pageSize: Int, hasNext: Bool) {
        self.items = items
        self.page = page
        self.pageSize = pageSize
        self.hasNext = hasNext
    }

    /// 다음 장 요청. 마지막 장이면 nil.
    /// 호출부가 `page + 1` 을 손으로 계산하지 않게 여기서 닫는다.
    /// `pageSize <= 0` 은 `PageRequest.init` 이 이미 막지만, `Page` 를 직접 만드는 경로가 열려 있어
    /// 이중 방어로 남긴다 — 그런 값이 들어오면 무한히 빈 페이지를 요청하는 대신 멈춘다.
    public var next: PageRequest? {
        guard hasNext, pageSize > 0 else { return nil }
        return PageRequest(page: page + 1, pageSize: pageSize)
    }
}

// Item 에 제약을 걸지 않고 조건부로 연다 — Equatable 이 아닌 항목도 Page 로 담을 수 있어야 한다.
extension Page: Equatable where Item: Equatable {}
extension Page: Sendable where Item: Sendable {}
