import Foundation
import Domain

/// 백엔드 미연결 단계용 `SavePinRepository` 구현. 저장 API 가 없어 아무것도 남기지 않고
/// 네트워크처럼 잠깐 기다렸다 성공만 돌려준다 — 시트의 저장 중/완료 전이를 실물처럼 확인하려는 지연이다.
///
/// 추후 네트워크 `SavePinRepositoryImpl`(DTO → `toDomain()` 매핑) 로 교체하면 이 파일만 지운다.
/// 그때 실패 경로(중복 저장 알림 등)도 함께 붙는다.
public final class MockSavePinRepository: SavePinRepository {
    public init() {}

    public func save(pinID: PinID, toRoomIDs roomIDs: Set<String>) async throws {
        try? await Task.sleep(for: .milliseconds(300))
    }
}
