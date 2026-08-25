import Foundation

/// 홈 사용 가이드(스와이프 안내)를 이미 보여줬는지 기억하는 저장소 추상.
/// 저장 매체(UserDefaults·DB·서버)가 무엇인지 Domain 은 알지 못한다.
public protocol HomeGuideRepository: Sendable {
    func hasSeenHomeGuide() async -> Bool
    func markHomeGuideSeen() async
}
