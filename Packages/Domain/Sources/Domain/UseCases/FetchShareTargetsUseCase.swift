import Foundation

/// "다른 방에 공유" 시트가 그릴 방 목록을 가져온다 — 각 방에 이 장소가 이미 있는지까지 함께.
public protocol FetchShareTargetsUseCase: Sendable {
    func execute(pinID: PinID) async throws -> [ShareTarget]
}

public struct DefaultFetchShareTargetsUseCase: FetchShareTargetsUseCase {
    private let repository: SavePinRepository

    public init(repository: SavePinRepository) {
        self.repository = repository
    }

    public func execute(pinID: PinID) async throws -> [ShareTarget] {
        try await repository.shareTargets(pinID: pinID)
    }
}
