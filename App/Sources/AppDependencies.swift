import Core
import Data
import Domain
import Feature
import FeatureArchive
import FeatureHome
import FeatureNotification
import FeatureOnboarding
import Foundation
import Networking

/// 컴포지션 루트(Composition Root).
/// 앱 타깃만이 구체 타입을 알고, 의존성 그래프를 손으로 조립한다.
/// 각 Coordinator 의 deps 프로토콜(`MemberDeps`·`HomeDeps`·`ArchiveDeps` 등)을 이 한 타입이 준수한다.
struct AppDependencies: MemberDeps, HomeDeps, ArchiveDeps, NotificationDeps, LaunchDeps, OnboardingDeps {
    let fetchMember: FetchMemberUseCase
    let fetchRooms: FetchRoomsUseCase
    let fetchPins: FetchPinsUseCase
    let fetchNotifications: FetchNotificationsUseCase
    let lastViewedRoom: LastViewedRoomUseCase
    let homeGuide: HomeGuideUseCase
    let savePin: SavePinToRoomsUseCase
    let fetchPinDetail: FetchPinDetailUseCase
    let fetchShareTargets: FetchShareTargetsUseCase
    let currentMember: CurrentMemberUseCase
    let createRoom: CreateRoomUseCase
    let roomCreationPromptSnooze: SnoozeSwitch
    let ensureSession: EnsureSessionUseCase
    let onboarding: OnboardingUseCase
    /// 실 API 를 태우는 클라이언트. Repository 구현에 그대로 넘긴다
    /// (절차: Packages/Networking/Docs/AddingAPI.md).
    let httpClient: HTTPClient

    /// 서버가 하나라 여기서 직접 든다. 로컬·스테이징이 생기면 그때 환경 분기를 만든다.
    private static let baseURL = URL(string: "https://api.gguk.org")!

    init() {
        // 인증 토큰은 클라이언트가 요청마다 붙인다. 여기서 빠뜨리면 컴파일은 통과한 채
        // 인증이 필요한 API 가 전부 401 을 받는다.
        self.httpClient = URLSessionHTTPClient(
            baseURL: Self.baseURL,
            tokenProvider: FirebaseAuthTokenProvider()
        )

        // 백엔드 미연결 단계 — 시범용 Stub UseCase 를 주입한다.
        // 실 API 연결 절차는 Packages/Networking/Docs/AddingAPI.md 참조.
        self.fetchMember = StubFetchMemberUseCase()

        // 목 저장소는 인스턴스를 공유한다 — 방/핀/저장 상태가 서로를 참조하므로 따로 만들면
        // "이미 저장된 방" 같은 관계적 사실이 저장소마다 달라진다.
        let rooms = MockRoomRepository()
        let pins = MockPinRepository()

        // 방 목록: 실 API 미연결 → Mock Repository(하드코딩 JSON) 사용. 추후 RoomRepositoryImpl 로 교체.
        self.fetchRooms = DefaultFetchRoomsUseCase(repository: rooms)

        // 홈 카드 핀: 실 API 미연결 → Mock Repository(하드코딩 장소 풀) 사용. 추후 PinRepositoryImpl 로 교체.
        // 목록과 상세를 한 인스턴스가 겸한다 — 상세가 목록에 없는 값을 지어내면 두 화면이 어긋난다.
        self.fetchPins = DefaultFetchPinsUseCase(repository: pins)
        self.fetchPinDetail = DefaultFetchPinDetailUseCase(repository: pins)

        // 알림 목록: 실 API 미연결 → Mock Repository(하드코딩 JSON) 사용. 추후 NotificationRepositoryImpl 로 교체.
        self.fetchNotifications = DefaultFetchNotificationsUseCase(repository: MockNotificationRepository())

        // 마지막으로 본 방: 방 id 하나만 남기면 되는 로컬 기록이라 UserDefaults 구현을 쓴다.
        self.lastViewedRoom = DefaultLastViewedRoomUseCase(
            repository: UserDefaultsLastViewedRoomRepository()
        )

        // 홈 사용 가이드 1회 표기 플래그도 같은 이유로 UserDefaults.
        self.homeGuide = DefaultHomeGuideUseCase(repository: UserDefaultsHomeGuideRepository())

        // 다른 방 저장: 저장 API 미연결 → Mock Repository 사용. 어느 방에 담았는지를 메모리에
        // 들고 있어야 "이미 저장된 방" 표시가 목업에서도 산다. 추후 SavePinRepositoryImpl 로 교체.
        let savePinRepository = MockSavePinRepository(rooms: rooms, pins: pins)
        self.savePin = DefaultSavePinToRoomsUseCase(repository: savePinRepository)
        self.fetchShareTargets = DefaultFetchShareTargetsUseCase(repository: savePinRepository)

        // 지금 앱을 쓰는 사람: 프로필 API 미연결 → Mock. MockRoomRepository 의 user-0001 과 같은 사람이다.
        self.currentMember = DefaultCurrentMemberUseCase(repository: MockCurrentMemberRepository())

        // 방 생성: 실 API. 편집(UpdateRoomUseCase)은 진입점이 아직 없어 조립하지 않는다.
        self.createRoom = DefaultCreateRoomUseCase(
            repository: RoomEditingRepositoryImpl(client: httpClient)
        )

        // 공동방 생성 유도 시트: "나중에 만들래요" 를 누르면 2주 동안 띄우지 않는다(기획 001-2-1).
        self.roomCreationPromptSnooze = SnoozeSwitch(key: "roomCreationPrompt.snoozedAt", period: .days(14))

        // 가입 없는 익명 인증. 구현이 Data 가 아니라 App 에 있는 건 Firebase SDK 의존을
        // 로컬 패키지로 내리지 않기 위해서다 — SDK 어댑터는 컴포지션 루트가 갖는다.
        self.ensureSession = DefaultEnsureSessionUseCase(repository: FirebaseAuthRepository())

        // 온보딩 1회 표기 플래그도 홈 가이드와 같은 이유로 UserDefaults.
        self.onboarding = DefaultOnboardingUseCase(repository: UserDefaultsOnboardingRepository())
    }
}

/// 백엔드가 붙기 전까지 시범 화면을 동작시키는 임시 Stub. 실제 API 연결 시 제거한다.
struct StubFetchMemberUseCase: FetchMemberUseCase {
    func execute(id: MemberID) async throws -> Member {
        try? await Task.sleep(nanoseconds: 300_000_000)   // 로딩 상태 시범용 지연
        return Member(id: id, name: "김유빈", email: "newbean@mashup.kr")
    }
}
