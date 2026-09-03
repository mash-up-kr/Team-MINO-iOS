import Core
import Data
import Domain
import Feature
import FeatureArchive
import FeatureHome
import FeatureNotification
import FeatureOnboarding
import FeatureProfile
import Foundation
import Networking

/// 컴포지션 루트(Composition Root).
/// 앱 타깃만이 구체 타입을 알고, 의존성 그래프를 손으로 조립한다.
/// 각 Coordinator 의 deps 프로토콜(`MemberDeps`·`HomeDeps`·`ArchiveDeps` 등)을 이 한 타입이 준수한다.
struct AppDependencies: MemberDeps, HomeDeps, ArchiveDeps, NotificationDeps, LaunchDeps, OnboardingDeps, ProfileDeps {
    let fetchMember: FetchMemberUseCase
    let fetchRooms: FetchRoomsUseCase
    let fetchHomeCards: FetchHomeCardsUseCase
    let fetchRoomPins: FetchRoomPinsUseCase
    let fetchNotifications: FetchNotificationsUseCase
    let lastViewedRoom: LastViewedRoomUseCase
    let homeGuide: HomeGuideUseCase
    let savePin: SavePinToRoomsUseCase
    let fetchPinDetail: FetchPinDetailUseCase
    let deletePin: DeletePinUseCase
    let fetchShareTargets: FetchShareTargetsUseCase
    let fetchSavedRooms: FetchSavedRoomsUseCase
    let currentMember: CurrentMemberUseCase
    /// 장소 상세의 "친구들의 코멘트" — 조회·등록·삭제. 화면 상태가 아니라 저장소에 남는다(#165).
    let fetchComments: FetchPinCommentsUseCase
    let postComment: PostPinCommentUseCase
    let deleteComment: DeletePinCommentUseCase
    let createRoom: CreateRoomUseCase
    let roomCreationPromptSnooze: SnoozeSwitch
    let ensureSession: EnsureSessionUseCase
    let registerProfile: RegisterProfileUseCase
    /// 앱 진입 분기(`LaunchDeps`)가 등록 여부를 묻는 데 쓴다 — 프로필이 있으면 온보딩을 마친 것이다.
    /// 마이페이지 프로필 설정(`.edit`)도 진입하면서 이걸로 현재 값을 채운다.
    let fetchProfile: FetchProfileUseCase
    /// 마이페이지가 **첫 프레임에** 그릴 프로필. 서버를 기다리지 않고 이번 실행에서 마지막으로
    /// 읽은 값을 준다 — 등록·조회·수정 유스케이스가 지나가며 채워 둔다.
    let lastKnownProfile: LastKnownProfileUseCase
    let recordPinAccess: RecordPinAccessUseCase
    let updateProfile: UpdateProfileUseCase
    let notificationSetting: NotificationSettingUseCase
    let locationSetting: LocationSettingUseCase
    /// 방 상세 거리순 정렬(004-1 ⑥)의 기준점 — "내 기준 3km" 를 재려면 내 위치가 있어야 한다.
    let currentLocation: CurrentLocationUseCase
    let fetchInviteCode: FetchInviteCodeUseCase
    /// 초대 링크의 스킴·호스트. 서버는 코드만 주고 링크는 앱이 조립한다(`Core.DeeplinkBuilder`).
    ///
    /// > 스킴 `gguk` 은 `Info.plist` 의 `CFBundleURLTypes` 와도 맞아야 한다 —
    /// > 어긋나면 빌드·테스트는 통과하고 링크만 조용히 안 열린다.
    let deeplink: DeeplinkConfiguration
    /// 들어온 URL 을 목적지로 번역한다. 링크를 **만드는** 쪽(`DeeplinkBuilder`)과 같은
    /// 설정을 보도록 조립을 여기 한곳에 둔다 — 갈리면 우리가 만든 링크를 우리가 못 읽는다.
    let deeplinkParser: DeeplinkParser
    /// 실 API 를 태우는 클라이언트. Repository 구현에 그대로 넘긴다
    /// (절차: Packages/Networking/Docs/AddingAPI.md).
    let httpClient: HTTPClient

    // 권한 어댑터(`SystemPermissionRepository`)가 MainActor 격리라 조립도 메인에서 한다.
    // 실제 생성 지점(`MINOApp.init`·프리뷰)이 모두 MainActor 라 제약이 되지 않는다.
    @MainActor
    init() {
        // 인증 토큰은 클라이언트가 요청마다 붙인다. 여기서 빠뜨리면 컴파일은 통과한 채
        // 인증이 필요한 API 가 전부 401 을 받는다.
        self.httpClient = URLSessionHTTPClient(
            baseURL: APIEnvironment.baseURL,
            tokenProvider: FirebaseAuthTokenProvider()
        )

        // 백엔드 미연결 단계 — 시범용 Stub UseCase 를 주입한다.
        // 실 API 연결 절차는 Packages/Networking/Docs/AddingAPI.md 참조.
        self.fetchMember = StubFetchMemberUseCase()

        // 방 목록: 실 API(`GET /api/v1/rooms?showUsers=true`). 멤버 얼굴을 그리는 화면이 있어
        // showUsers 를 켠 채로 받는다(RoomAPI.list 주석).
        let rooms = RoomRepositoryImpl(client: httpClient)

        // 저장한 장소: 실 API. 홈 카드 덱(`GET /rooms/{roomId}/cards`)·방 상세 목록
        // (`GET /pins?roomId=`)·장소 상세(`GET /pins/{pinId}`)를 한 인스턴스가 겸한다 —
        // 상세가 목록에 없는 값을 지어내면 두 화면이 어긋난다.
        let pins = PinRepositoryImpl(client: httpClient)

        self.fetchRooms = DefaultFetchRoomsUseCase(repository: rooms)

        self.fetchHomeCards = DefaultFetchHomeCardsUseCase(repository: pins)
        self.fetchRoomPins = DefaultFetchRoomPinsUseCase(repository: pins)
        self.fetchPinDetail = DefaultFetchPinDetailUseCase(repository: pins)
        // 「경과일 초기화 확인」(홈 spec FR-007) — 상세를 연 사실을 서버에 남긴다.
        self.recordPinAccess = DefaultRecordPinAccessUseCase(repository: pins)
        // 삭제만 스텁이다 — 서버에 삭제 엔드포인트가 없다(`StubPinDeletionRepository` 주석).
        self.deletePin = DefaultDeletePinUseCase(repository: StubPinDeletionRepository())

        // 알림 목록: 실 API 미연결 → Mock Repository(하드코딩 JSON) 사용. 추후 NotificationRepositoryImpl 로 교체.
        self.fetchNotifications = DefaultFetchNotificationsUseCase(repository: MockNotificationRepository())

        // 마지막으로 본 방: 방 id 하나만 남기면 되는 로컬 기록이라 UserDefaults 구현을 쓴다.
        self.lastViewedRoom = DefaultLastViewedRoomUseCase(
            repository: UserDefaultsLastViewedRoomRepository()
        )

        // 홈 사용 가이드 1회 표기 플래그도 같은 이유로 UserDefaults.
        self.homeGuide = DefaultHomeGuideUseCase(repository: UserDefaultsHomeGuideRepository())

        // 「다른 방에 공유」(011-1) — 저장과 조회가 서로 다른 엔드포인트다(place-api.md §3·§4).
        // 저장은 핀 id 로 `POST /pins/{pinId}/duplicate`, 후보 조회는 **장소 id** 로
        // `GET /rooms?showHasPlaceId=` 다. 같은 장소도 방마다 핀 id 가 달라 조회는 장소 기준이다.
        let shareTargets = ShareTargetRepositoryImpl(client: httpClient)
        self.savePin = DefaultSavePinToRoomsUseCase(repository: SavePinRepositoryImpl(client: httpClient))
        self.fetchShareTargets = DefaultFetchShareTargetsUseCase(repository: shareTargets)
        // 저장된 방(014)도 같은 조회를 쓴다 — "방 목록 + 그 방에 이 장소가 있는지" 가 이미 한
        // 응답으로 오므로 저장된 방만 따로 물을 API 가 필요 없다.
        self.fetchSavedRooms = DefaultFetchSavedRoomsUseCase(repository: shareTargets)

        // 지금 앱을 쓰는 사람: 프로필 API 미연결 → Mock. MockRoomRepository 의 user-0001 과 같은 사람이다.
        let currentMemberRepository = MockCurrentMemberRepository()
        self.currentMember = DefaultCurrentMemberUseCase(repository: currentMemberRepository)

        // 코멘트: 실 API 미연결 → Mock. 등록·삭제가 메모리에 남아야 시트를 닫았다 다시 열어도
        // 쓴 코멘트가 그대로다(#165). 핀 저장소를 함께 넘기는 건 카드가 보여 준 "코멘트 N" 만큼
        // 친구 코멘트를 깔아 두기 위해서고, 신원 저장소는 등록한 코멘트의 작성자를 구하는 자리다
        // (실 서버는 토큰에서 뽑으므로 인터페이스가 작성자를 받지 않는다).
        // 추후 PinCommentRepositoryImpl 로 교체.
        let comments = MockPinCommentRepository(pins: pins, currentMember: currentMemberRepository)
        self.fetchComments = DefaultFetchPinCommentsUseCase(repository: comments)
        self.postComment = DefaultPostPinCommentUseCase(repository: comments)
        self.deleteComment = DefaultDeletePinCommentUseCase(repository: comments)

        // 방 생성: 실 API. 편집(UpdateRoomUseCase)은 진입점이 아직 없어 조립하지 않는다.
        self.createRoom = DefaultCreateRoomUseCase(
            repository: RoomEditingRepositoryImpl(client: httpClient)
        )

        // 공동방 생성 유도 시트: "나중에 만들래요" 를 누르면 2주 동안 띄우지 않는다(기획 001-2-1).
        self.roomCreationPromptSnooze = SnoozeSwitch(key: "roomCreationPrompt.snoozedAt", period: .days(14))

        // 가입 없는 익명 인증. 구현이 Data 가 아니라 App 에 있는 건 Firebase SDK 의존을
        // 로컬 패키지로 내리지 않기 위해서다 — SDK 어댑터는 컴포지션 루트가 갖는다.
        self.ensureSession = DefaultEnsureSessionUseCase(repository: FirebaseAuthRepository())

        // 세 프로필 유스케이스가 **같은 캐시**를 지난다 — 어느 경로로 프로필을 얻었든(앱 시작의
        // 등록 여부 판단 포함) 다음 마이페이지 진입의 첫 프레임이 채워진다.
        let profileCache = InMemoryLastKnownProfileRepository()
        self.lastKnownProfile = DefaultLastKnownProfileUseCase(cache: profileCache)

        // 프로필 등록: 실 API(POST /api/v1/users). 등록은 인증 미들웨어를 부분만 타므로
        // (UserAPI.register 의 .unregisteredUser) 세션만 있으면 최초 진입에서도 통과한다.
        self.registerProfile = DefaultRegisterProfileUseCase(
            repository: ProfileRepositoryImpl(client: httpClient),
            cache: profileCache
        )

        // 온보딩 여부 판단: 실 API(GET /api/v1/users/me). 로컬 플래그를 쓰지 않는 이유는
        // AppLaunchStore.establishSession 주석 참조.
        self.fetchProfile = DefaultFetchProfileUseCase(
            repository: ProfileRepositoryImpl(client: httpClient),
            cache: profileCache
        )

        // 프로필 수정: 실 API(PATCH /api/v1/users/me). 마이페이지 프로필 설정의 저장이다.
        self.updateProfile = DefaultUpdateProfileUseCase(
            repository: ProfileRepositoryImpl(client: httpClient),
            cache: profileCache
        )

        // 권한 어댑터는 플랫폼 프레임워크(UserNotifications·CoreLocation)를 타므로 여기서 만든다
        // — `FirebaseAuthRepository` 와 같은 이유로 Data 가 아니라 컴포지션 루트가 갖는다.
        let permissions = SystemPermissionRepository()
        self.notificationSetting = DefaultNotificationSettingUseCase(
            permissions: permissions,
            settings: UserDefaultsAppSettingsRepository(),
            push: RemoteNotificationRegistrationRepository()
        )
        self.locationSetting = DefaultLocationSettingUseCase(permissions: permissions)

        // 1회 측위는 권한 저장소와 CLLocationManager 를 나눠 갖는다 — 이유는
        // SystemCurrentLocationRepository 주석(한 delegate 에 두 종류 콜백을 얹지 않는다).
        self.currentLocation = DefaultCurrentLocationUseCase(
            permissions: permissions,
            location: SystemCurrentLocationRepository()
        )

        // 초대 코드: 실 API(POST /api/v1/rooms/{roomId}/invitations).
        self.fetchInviteCode = DefaultFetchInviteCodeUseCase(
            repository: InvitationRepositoryImpl(client: httpClient)
        )

        self.deeplink = DeeplinkConfiguration(scheme: "gguk", host: "gguk.org")
        self.deeplinkParser = DeeplinkParser(configuration: self.deeplink)
    }
}

/// 백엔드가 붙기 전까지 시범 화면을 동작시키는 임시 Stub. 실제 API 연결 시 제거한다.
struct StubFetchMemberUseCase: FetchMemberUseCase {
    func execute(id: MemberID) async throws -> Member {
        try? await Task.sleep(nanoseconds: 300_000_000)   // 로딩 상태 시범용 지연
        return Member(id: id, name: "김유빈", email: "newbean@mashup.kr")
    }
}
