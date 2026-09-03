import Foundation

/// 지금 앱을 쓰고 있는 사람이 누구인지 알려주는 저장소 추상.
///
/// `AuthRepository` 와 나눈다 — 그쪽은 "서버와 통신할 수 있는 상태인가"(세션 확보)를 다루고,
/// 이쪽은 "그 사람이 누구인가"(표시·권한 판정에 쓰는 신원)를 다룬다.
public protocol CurrentMemberRepository: Sendable {
    func currentMember() async throws -> MemberProfile
}
