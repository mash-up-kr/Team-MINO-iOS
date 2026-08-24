import Foundation

/// 앱을 다시 켰을 때 마지막으로 보던 방부터 이어 보도록, 마지막으로 본 방을 기억한다.
/// (홈 정책: 최초 실행은 "내 장소"부터, 이후 실행은 마지막으로 본 방부터)
public protocol LastViewedRoomUseCase: Sendable {
    /// 마지막으로 본 방의 id. 기록이 없으면 nil.
    func load() async -> String?
    func save(roomID: String) async
}

public struct DefaultLastViewedRoomUseCase: LastViewedRoomUseCase {
    private let repository: LastViewedRoomRepository

    public init(repository: LastViewedRoomRepository) {
        self.repository = repository
    }

    public func load() async -> String? {
        await repository.lastViewedRoomID()
    }

    public func save(roomID: String) async {
        await repository.saveLastViewedRoomID(roomID)
    }
}
