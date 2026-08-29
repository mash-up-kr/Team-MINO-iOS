import Domain
import Foundation
import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
/// 화면 위에 떠 있는 확인 다이얼로그. 없으면 `nil`.
///
/// 셋 다 결론이 "OS 설정 앱으로 보낸다" 로 같지만 문구가 달라 케이스를 나눈다.
public enum ProfileMainDialog: Equatable, Identifiable, Sendable {
    /// 알림 권한이 이미 거부돼 시스템 팝업이 다시 뜨지 않는다(EC-003).
    case notificationBlocked
    /// 위치 권한이 이미 거부돼 시스템 팝업이 다시 뜨지 않는다(EC-003).
    case locationBlocked
    /// 켜진 위치 스위치를 끄려 한다 — 앱은 이미 준 권한을 스스로 못 뺏는다(EC-007·FR-015).
    case locationTurnOff

    public var id: Self { self }
}

public struct ProfileMainState: Equatable {
    /// 아직 한 번도 못 읽었으면 비어 있다. 화면의 나머지(앱 설정·서비스 정보)는 프로필과 무관하게 그린다.
    public var nickname: String
    /// 서버가 주는 아바타 식별자는 **색**이다(`avatar.color`) — 그림으로 옮기는 건 화면의 몫이다.
    /// 아직 아바타가 없는 계정이 있어 옵셔널이다.
    public var avatarColor: AvatarColor?
    /// 표시값은 OS 알림 권한과 앱 자체 발송 설정의 **합성**이다(spec §2.3) — 계산은 UseCase 가 한다.
    public var isNotificationOn: Bool
    /// 표시값이 곧 OS 위치 권한 상태다(spec §2.3).
    public var isLocationOn: Bool
    /// 스위치를 켜고 끄는 요청이 진행 중인가. 응답이 올 때까지 그 행을 잠근다.
    ///
    /// 두 가지를 동시에 막는다. ① 연타·반대 방향 재탭 — 위치가 꺼져 있는데 "끌 수 없어요" 안내가
    /// 뜨는 엉뚱한 경로가 여기서 생긴다. ② 진행 중인 요청과 ``ProfileMainAction/syncSwitches`` 의
    /// 경합 — 권한 팝업이 뜨면 앱이 비활성→활성으로 돌아오며 재조회가 발사되는데, 그 결과가
    /// 늦게 도착해 방금 확정된 값을 덮을 수 있다.
    public var isNotificationBusy: Bool
    public var isLocationBusy: Bool
    public var dialog: ProfileMainDialog?

    public init() {
        self.nickname = ""
        self.avatarColor = nil
        self.isNotificationOn = false
        self.isLocationOn = false
        self.isNotificationBusy = false
        self.isLocationBusy = false
        self.dialog = nil
    }
}

public enum ProfileMainAction: Equatable {
    /// 진입·복귀 시 프로필 재조회(FR-009). 스위치 동기화와 **나눠 둔다** — 묶으면 즉시 읽히는
    /// 권한 상태가 네트워크 왕복을 기다리게 된다.
    case loadProfile
    case profileLoaded(Profile)          // Response Action (성공)
    case profileLoadFailed(DomainError)  // Response Action (실패)

    /// 진입·복귀 시 두 스위치를 실제 상태와 재동기화(FR-009).
    case syncSwitches
    case switchesSynced(isNotificationOn: Bool, isLocationOn: Bool)

    case setNotification(Bool)
    case notificationActivated(PermissionActivation)   // 켜기 결과
    case notificationTurnedOff                         // 끄기 결과

    case setLocation(Bool)
    case locationActivated(PermissionActivation)       // 켜기 결과

    case dismissDialog
    /// 다이얼로그의 확인 — 세 경우 모두 OS 설정 앱으로 보낸다.
    case confirmDialog

    case tapEditProfile
    case tapTerms
    case tapAppReview
}

public enum ProfileMainNav: Equatable, Sendable {
    /// 프로필 설정 화면으로(FR-002).
    ///
    /// **기존 값을 실어 나르지 않는다** — 설정 화면이 `edit` 모드로 진입하며 스스로 조회해 채운다
    /// (`ProfileSetupUI.ProfileSetupState.mode`). 여기서 함께 넘기면 같은 값을 두 곳에서 읽어
    /// 마이페이지가 늦게 갱신됐을 때 편집 화면이 옛 값으로 열린다.
    case pushProfileSetup
    case openURL(URL)
    case openSystemSettings
}

public typealias ProfileMainStore = Store<ProfileMainState, ProfileMainAction, ProfileMainNav>

public func profileMainReducer(
    fetchProfile: FetchProfileUseCase,
    notification: NotificationSettingUseCase,
    location: LocationSettingUseCase
) -> (inout ProfileMainState, ProfileMainAction) -> Effect<ProfileMainAction, ProfileMainNav> {
    { state, action in
        switch action {
        case .loadProfile:
            return .run { send in
                do {
                    send(.profileLoaded(try await fetchProfile.execute()))
                } catch is CancellationError {
                    return   // 취소는 결과가 없는 것이지 실패가 아니다
                } catch {
                    send(.profileLoadFailed(error as? DomainError ?? .profileFetchFailed))
                }
            }

        case .profileLoaded(let profile):
            state.nickname = profile.nickname
            state.avatarColor = profile.avatarColor
            return .none

        // **마지막으로 읽은 값을 지우지 않는다.** 재조회는 복귀할 때마다 일어나므로(FR-009) 이 경로는
        // 최초 진입뿐 아니라 "이미 잘 보여주던 화면" 에서도 밟힌다. 지워 버리면 저장하고 돌아온 직후
        // 잠깐 끊긴 것만으로 방금 저장한 프로필이 사라져 보이고, 그 상태로 연필을 누르면 편집 화면이
        // 빈 채로 열려 FR-002(기존 값이 채워진 채)까지 깨진다.
        // 한 번도 못 읽었으면 초기값이 이미 비어 있어 "프로필 영역만 빈" 표시가 그대로 유지된다.
        case .profileLoadFailed:
            return .none

        case .syncSwitches:
            return .run { send in
                async let isNotificationOn = notification.isOn()
                async let isLocationOn = location.isOn()
                send(.switchesSynced(
                    isNotificationOn: await isNotificationOn,
                    isLocationOn: await isLocationOn
                ))
            }

        // 진행 중인 축은 덮지 않는다 — 재조회가 그 요청보다 늦게 끝나면 방금 확정된 값을 되돌린다.
        case .switchesSynced(let isNotificationOn, let isLocationOn):
            if !state.isNotificationBusy { state.isNotificationOn = isNotificationOn }
            if !state.isLocationBusy { state.isLocationOn = isLocationOn }
            return .none

        // 표시값(`isNotificationOn`)은 권한이 확정된 뒤에만 바꾼다 — 낙관적 업데이트 금지(UX-003).
        // 대신 `busy` 를 세워 요청 양 끝에서 state 가 반드시 변하게 한다: 그래야 사용자가 거부해
        // 표시값이 그대로일 때도 재렌더가 걸려 스위치가 제자리로 돌아온다.
        case .setNotification(let isOn):
            guard !state.isNotificationBusy else { return .none }
            state.isNotificationBusy = true
            if isOn {
                return .run { send in send(.notificationActivated(await notification.turnOn())) }
            }
            // 끄기는 OS 권한을 건드리지 않는다. 앱 쪽 발송만 멈춘다(FR-014).
            return .run { send in
                await notification.turnOff()
                send(.notificationTurnedOff)
            }

        case .notificationActivated(let activation):
            state.isNotificationBusy = false
            switch activation {
            case .activated: state.isNotificationOn = true
            case .rejected: break                                  // OFF 를 유지한다
            case .needsSystemSettings: state.dialog = .notificationBlocked
            }
            return .none

        case .notificationTurnedOff:
            state.isNotificationBusy = false
            state.isNotificationOn = false
            return .none

        case .setLocation(let isOn):
            guard !state.isLocationBusy else { return .none }
            guard isOn else {
                // 앱이 이미 받은 위치 권한을 스스로 취소할 수 없다 — 사유를 안내하고 설정으로 보낸다(FR-015).
                state.dialog = .locationTurnOff
                return .none
            }
            state.isLocationBusy = true
            return .run { send in send(.locationActivated(await location.turnOn())) }

        case .locationActivated(let activation):
            state.isLocationBusy = false
            switch activation {
            case .activated: state.isLocationOn = true
            case .rejected: break
            case .needsSystemSettings: state.dialog = .locationBlocked
            }
            return .none

        case .dismissDialog:
            state.dialog = nil
            return .none

        case .confirmDialog:
            state.dialog = nil
            return .navigate(.openSystemSettings)

        case .tapEditProfile:
            return .navigate(.pushProfileSetup)

        case .tapTerms:
            return .navigate(.openURL(ProfileServiceLinks.terms))

        // 앱 ID 가 정해지기 전에는 열 곳이 없다 — 아무 일도 하지 않는다(ProfileServiceLinks 주석).
        case .tapAppReview:
            guard let url = ProfileServiceLinks.appReview else { return .none }
            return .navigate(.openURL(url))
        }
    }
}
