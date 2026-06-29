import Observation
import Domain

/// MemberProfile 화면의 상태를 관리하는 ViewModel.
/// UseCase 만 알고 Data/Networking 같은 인프라는 알지 못한다.
/// 화면 상태(State)는 메인 액터에서만 변경된다.
@MainActor
@Observable
public final class MemberProfileViewModel {
    public enum State: Equatable, Sendable {
        case idle
        case loading
        case loaded(Member)
        case failed(message: String)
    }

    public private(set) var state: State = .idle

    private let useCase: any FetchMemberUseCase
    private let memberID: MemberID
    /// load() 재진입 시 더 늦게 시작한 요청만 state 를 갱신하도록 하는 세대 토큰.
    /// 느린 이전 요청이 새 요청의 결과를 덮어쓰는 stale-wins 레이스를 막는다.
    private var loadGeneration = 0

    public init(useCase: any FetchMemberUseCase, memberID: MemberID) {
        self.useCase = useCase
        self.memberID = memberID
    }

    public func load() async {
        loadGeneration &+= 1
        let generation = loadGeneration
        state = .loading
        do {
            let member = try await useCase.execute(id: memberID)
            guard generation == loadGeneration else { return }
            state = .loaded(member)
        } catch {
            guard generation == loadGeneration else { return }
            state = .failed(message: Self.message(for: error))
        }
    }

    /// 인프라 오류가 아닌 도메인 어휘로 사용자 메시지를 만든다.
    private static func message(for error: Error) -> String {
        switch error {
        case DomainError.memberNotFound:
            return "회원을 찾을 수 없어요"
        case DomainError.unauthorized:
            return "접근 권한이 없어요"
        default:
            return "회원 정보를 불러오지 못했어요"
        }
    }
}
