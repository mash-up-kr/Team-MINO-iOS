import Foundation

/// 「경과일 초기화 확인」 — 장소 상세를 연 사실을 서버에 알린다.
///
/// 홈 카드 덱의 **두 확인 이벤트 중 ①**이다(spec §5 확정 항목).
///
/// | | 발생 | 쓰임 | 기록 |
/// |---|---|---|---|
/// | ① 경과일 초기화 확인 | 장소 상세를 연 시점 | 꾹 Pick 경과일 초기화 | 서버 |
/// | ② 카드 열람 확인 | 카드를 좌→우로 넘김 | 덱 소진 판정 | 클라이언트 |
///
/// 둘은 서로 독립이다 — 카드를 넘기는 것은 서버에 알리지 않고, 상세를 여는 것은 덱을 건드리지 않는다.
/// 되돌리기가 취소하는 것도 ②뿐이라 여기서 보낸 기록은 되돌리지 않는다.
public protocol RecordPinAccessUseCase: Sendable {
    func execute(pinID: PinID) async throws
}

public struct DefaultRecordPinAccessUseCase: RecordPinAccessUseCase {
    private let repository: PinAccessRepository

    public init(repository: PinAccessRepository) {
        self.repository = repository
    }

    public func execute(pinID: PinID) async throws {
        try await repository.recordAccess(pinID: pinID)
    }
}
