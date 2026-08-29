import Domain
import Foundation

/// 삭제 API 가 없는 동안 `PinDeletionRepository` 자리를 채우는 스텁.
///
/// ⚠️ **서버에 핀 삭제 엔드포인트가 아예 없다**(`DELETE /api/v1/pins/{pinId}` 부재 — 스펙 확인).
/// 그래서 이 구현은 성공만 돌려주고 아무것도 지우지 않는다. 화면은 지운 장소를 자기 상태에서
/// 빼므로 그 화면에서는 사라지지만, **다시 들어오면 되살아난다.**
///
/// 목록이 목이던 시절에는 지운 id 를 기억해 다음 조회에서 뺐지만(`MockPinRepository`),
/// 목록이 실 API 로 넘어간 지금은 기억해 봐야 서버 응답을 거를 자리가 없다 — 클라이언트에서
/// 거르면 "지웠는데 다른 기기에는 남아 있는" 상태를 진짜인 것처럼 보이게 할 뿐이다.
///
/// 엔드포인트가 생기면 `PinRepositoryImpl` 에 삭제를 붙이고 이 파일을 지운다.
///
/// 네트워크처럼 잠깐 기다렸다 성공하는 지연은 확인 버튼이 잠기는 걸 실물처럼 보기 위한 것이다.
public struct StubPinDeletionRepository: PinDeletionRepository {
    public init() {}

    public func delete(pinID: PinID) async throws {
        try? await Task.sleep(for: .milliseconds(300))
    }
}
