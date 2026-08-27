import Foundation

/// 방 상세의 장소 카드 케밥 → "장소 삭제" 로 그 장소를 방에서 지운다(시안 004-1 ⑧).
/// 하나의 비즈니스 유스케이스 = 하나의 UseCase. UI 관심사(확인 다이얼로그, 목록 갱신)는 포함하지 않는다.
public protocol DeletePinUseCase: Sendable {
    func execute(pinID: PinID) async throws
}

public struct DefaultDeletePinUseCase: DeletePinUseCase {
    private let repository: PinDeletionRepository

    public init(repository: PinDeletionRepository) {
        self.repository = repository
    }

    public func execute(pinID: PinID) async throws {
        try await repository.delete(pinID: pinID)
    }
}
