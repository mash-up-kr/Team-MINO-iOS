import Foundation

/// 홈 사용 가이드는 최초 진입 때 한 번만 보여준다 — 그 1회 표기 여부를 판단·기록한다.
public protocol HomeGuideUseCase: Sendable {
    /// 이미 보여줬으면 true (= 다시 띄우지 않는다).
    func hasSeen() async -> Bool
    func markSeen() async
}

public struct DefaultHomeGuideUseCase: HomeGuideUseCase {
    private let repository: HomeGuideRepository

    public init(repository: HomeGuideRepository) {
        self.repository = repository
    }

    public func hasSeen() async -> Bool {
        await repository.hasSeenHomeGuide()
    }

    public func markSeen() async {
        await repository.markHomeGuideSeen()
    }
}
