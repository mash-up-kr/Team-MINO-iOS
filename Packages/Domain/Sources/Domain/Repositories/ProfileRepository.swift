import Foundation

/// 도메인 관점에서 내 프로필에 접근하는 추상 인터페이스.
/// 구현체(Data 계층)가 API/DB/Cache 중 무엇을 쓰는지 Domain 은 알지 못한다.
public protocol ProfileRepository: Sendable {
    /// 유저 등록. 서버는 이때 개인방도 함께 만든다(`POST /api/v1/users`).
    func register(nickname: String, avatarColor: AvatarColor) async throws -> Profile
    func me() async throws -> Profile
    /// 부분 수정 — 넘긴 항목만 바뀐다(`PATCH /api/v1/users/me`).
    func update(nickname: String?, avatarColor: AvatarColor?) async throws -> Profile
}
