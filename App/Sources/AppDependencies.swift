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
    let lastViewedRoom: LastViewedRoomUseCase
    let homeGuide: HomeGuideUseCase

    init() {
        // 백엔드 미연결 단계 — 시범용 Stub UseCase 를 주입한다.
        // 실제 API 준비 시 아래 한 줄을 교체한다 (import Networking 추가):
        //   let client = URLSessionHTTPClient(baseURL: URL(string: "<real-base-url>")!)
        //   let repository = MemberRepositoryImpl(client: client)
        //   self.fetchMember = DefaultFetchMemberUseCase(repository: repository)
        self.fetchMember = StubFetchMemberUseCase()

        // 방 목록: 실 API 미연결 → Mock Repository(하드코딩 JSON) 사용. 추후 RoomRepositoryImpl 로 교체.
        self.fetchRooms = DefaultFetchRoomsUseCase(repository: MockRoomRepository())

        // 홈 카드 핀: 실 API 미연결 → Mock Repository(하드코딩 장소 풀) 사용. 추후 PinRepositoryImpl 로 교체.
        self.fetchPins = DefaultFetchPinsUseCase(repository: MockPinRepository())

        // 마지막으로 본 방: 방 id 하나만 남기면 되는 로컬 기록이라 UserDefaults 구현을 쓴다.
        self.lastViewedRoom = DefaultLastViewedRoomUseCase(
            repository: UserDefaultsLastViewedRoomRepository()
        )

        // 홈 사용 가이드 1회 표기 플래그도 같은 이유로 UserDefaults.
        self.homeGuide = DefaultHomeGuideUseCase(repository: UserDefaultsHomeGuideRepository())
    }
}

/// 백엔드가 붙기 전까지 시범 화면을 동작시키는 임시 Stub. 실제 API 연결 시 제거한다.
struct StubFetchMemberUseCase: FetchMemberUseCase {
    func execute(id: MemberID) async throws -> Member {
        try? await Task.sleep(nanoseconds: 300_000_000)   // 로딩 상태 시범용 지연
        return Member(id: id, name: "김유빈", email: "newbean@mashup.kr")
    }
}
