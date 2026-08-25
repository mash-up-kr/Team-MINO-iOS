import Foundation
import Domain

/// `LastViewedRoomRepository` 의 UserDefaults 구현.
/// 방 id 하나만 남기는 가벼운 기록이라 별도 저장소(DB)를 두지 않는다.
///
/// `@unchecked Sendable`: UserDefaults 는 스레드 안전하다고 문서화돼 있지만 Sendable 로 표시돼 있지 않다.
public struct UserDefaultsLastViewedRoomRepository: LastViewedRoomRepository, @unchecked Sendable {
    private static let key = "home.lastViewedRoomID"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func lastViewedRoomID() async -> String? {
        defaults.string(forKey: Self.key)
    }

    public func saveLastViewedRoomID(_ roomID: String) async {
        defaults.set(roomID, forKey: Self.key)
    }
}
