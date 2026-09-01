import Foundation

/// 방 하나를 식별자로 단독 조회하는 저장소 추상 — 방 목록을 거치지 않고 도착지를 세워야 하는
/// 경로(알림 탭에서 방·장소 상세로 이동)가 쓴다.
/// 구현체(Data 계층)가 API/DB/Mock 중 무엇을 쓰는지 Domain 은 알지 못한다.
public protocol RoomDetailRepository: Sendable {
    func room(id: String) async throws -> Room
}
