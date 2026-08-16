import Foundation

public struct Pin: Equatable, Identifiable, Sendable {
    public let id: PinID
    public let roomID: String
    public let category: PinCategory
    public let title: String
    public let address: String
    public let createdAt: Date

    public init(
        id: PinID,
        roomID: String,
        category: PinCategory,
        title: String,
        address: String,
        createdAt: Date
    ) {
        self.id = id
        self.roomID = roomID
        self.category = category
        self.title = title
        self.address = address
        self.createdAt = createdAt
    }
}
