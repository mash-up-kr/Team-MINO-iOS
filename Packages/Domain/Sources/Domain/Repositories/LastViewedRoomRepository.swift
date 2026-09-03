import Foundation

/// 사용자가 마지막으로 본 방을 기억하는 저장소 추상.
/// 저장 매체(UserDefaults·DB·서버)가 무엇인지 Domain 은 알지 못한다.
public protocol LastViewedRoomRepository: Sendable {
    /// 마지막으로 본 방의 id. 기록이 없으면 nil(앱 최초 실행).
    func lastViewedRoomID() async -> String?
    func saveLastViewedRoomID(_ roomID: String) async
}
