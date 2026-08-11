import Foundation

/// 도메인 관점에서 방(Room) 컬렉션에 접근하는 추상 인터페이스.
/// 구현체(Data 계층)가 API/DB/Cache/Mock 중 무엇을 쓰는지 Domain 은 알지 못한다.
public protocol RoomRepository: Sendable {
    func rooms() async throws -> [Room]
}
