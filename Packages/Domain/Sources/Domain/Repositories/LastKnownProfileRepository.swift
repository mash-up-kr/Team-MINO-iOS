import Foundation

/// 마지막으로 읽은 내 프로필을 기억하는 저장소 추상.
/// 저장 매체가 무엇인지 Domain 은 알지 못한다(``LastViewedRoomRepository`` 와 같은 결).
///
/// **조회가 동기다** — 화면이 *첫 프레임에* 그릴 값이라서다(``AppSettingsRepository`` 와 같은 이유).
/// `await` 로 한 틱 미루면 그 틱이 곧 "빈 화면 → 값" 바꿔치기가 되어, 이 저장소를 둔 이유가 사라진다.
public protocol LastKnownProfileRepository: Sendable {
    /// 마지막으로 읽은 프로필. 이번 실행에서 아직 한 번도 못 읽었으면 `nil`.
    func lastKnownProfile() -> Profile?
    func save(_ profile: Profile)
}
