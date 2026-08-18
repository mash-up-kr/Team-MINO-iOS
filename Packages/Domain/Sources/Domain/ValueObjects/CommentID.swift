import Foundation

/// 식별자 Value Object. 값 자체로 동등성을 비교하며 불변이다.
public struct CommentID: Equatable, Hashable, Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}
