import Foundation

/// 장소 상세에 필요한 핀 단독 조회 — 목록에는 없는 출처 링크(`sourceURL`)를 함께 얻는다.
public protocol FetchPinDetailUseCase: Sendable {
    func execute(pinID: PinID) async throws -> PinDetail
}

public struct DefaultFetchPinDetailUseCase: FetchPinDetailUseCase {
    private let repository: PinDetailRepository

    public init(repository: PinDetailRepository) {
        self.repository = repository
    }

    public func execute(pinID: PinID) async throws -> PinDetail {
        try await repository.pinDetail(id: pinID)
    }
}
