import Foundation

/// 고유 식별자(MemberID)로 구분되는 도메인 Entity.
/// 프레임워크에 의존하지 않는 순수 value type 이며 Codable 을 준수하지 않는다.
public struct Member: Equatable, Identifiable, Sendable {
    public let id: MemberID
    public let name: String
    public let email: String?

    public init(id: MemberID, name: String, email: String?) {
        self.id = id
        self.name = name
        self.email = email
    }
}
