import Foundation
import Domain

/// 「경과일 초기화 확인」 스파이 — 어느 핀으로 몇 번 나갔는지 센다.
///
/// 네 스위트가 같이 쓴다. `.load` 를 보내지 않는 스위트도 리듀서가 이 의존을 요구하므로
/// 기본값(성공·조용히)으로 받아 둔다.
actor SpyRecordPinAccess: RecordPinAccessUseCase {
    /// 서버가 기록을 거절하는 경우(EC-022) — 화면이 흔들리지 않는지 보려고 주입한다.
    private let failure: DomainError?
    private(set) var recorded: [PinID] = []

    init(failure: DomainError? = nil) {
        self.failure = failure
    }

    func execute(pinID: PinID) async throws {
        recorded.append(pinID)
        if let failure { throw failure }
    }
}
