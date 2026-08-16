import Data
import Domain
import Feature
import FeatureArchive
import FeatureHome

/// 컴포지션 루트(Composition Root).
/// 앱 타깃만이 구체 타입을 알고, 의존성 그래프를 손으로 조립한다.
/// 각 Coordinator 의 deps 프로토콜(`MemberDeps`·`HomeDeps`·`ArchiveDeps` 등)을 이 한 타입이 준수한다.
struct AppDependencies: MemberDeps, HomeDeps, ArchiveDeps {
    let fetchMember: FetchMemberUseCase
    let fetchRooms: FetchRoomsUseCase
    let fetchPins: FetchPinsUseCase

    init() {
        // 백엔드 미연결 단계 — 시범용 Stub UseCase 를 주입한다.
        // 실 API 연결 절차는 Packages/Networking/README.md 참조.
        self.fetchMember = StubFetchMemberUseCase()

        // 방 목록: 실 API 미연결 → Mock Repository(하드코딩 JSON) 사용. 추후 RoomRepositoryImpl 로 교체.
        self.fetchRooms = DefaultFetchRoomsUseCase(repository: MockRoomRepository())

        // 홈 카드 핀: 실 API 미연결 → Mock Repository(하드코딩 장소 풀) 사용. 추후 PinRepositoryImpl 로 교체.
        self.fetchPins = DefaultFetchPinsUseCase(repository: MockPinRepository())
    }
}

/// 백엔드가 붙기 전까지 시범 화면을 동작시키는 임시 Stub. 실제 API 연결 시 제거한다.
struct StubFetchMemberUseCase: FetchMemberUseCase {
    func execute(id: MemberID) async throws -> Member {
        try? await Task.sleep(nanoseconds: 300_000_000)   // 로딩 상태 시범용 지연
        return Member(id: id, name: "김유빈", email: "newbean@mashup.kr")
    }
}
