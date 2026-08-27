/// 도메인 관점에서 알림 컬렉션에 접근하는 추상 인터페이스.
/// 구현체(Data 계층)가 API/DB/Cache/Mock 중 무엇을 쓰는지 Domain 은 알지 못한다.
public protocol NotificationRepository: Sendable {
    /// 첫 장. **페이지 크기를 받지 않는다** — 기본 크기는 서버 사정이라 Data 계층이 알고 있고,
    /// 여기서 크기를 받으면 그 숫자가 화면 코드까지 올라온다.
    func notifications() async throws -> Page<AppNotification>
    /// 다음 장. `Page.next` 가 만들어 준 요청을 그대로 넘긴다.
    func notifications(_ request: PageRequest) async throws -> Page<AppNotification>
}
