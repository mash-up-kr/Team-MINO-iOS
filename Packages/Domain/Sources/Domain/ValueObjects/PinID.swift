public struct PinID: Equatable, Hashable, Sendable {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }
}
