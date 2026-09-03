import Domain
import MVI

/// Home(진입) 화면 상태 — 단일 `Equatable` struct (exhaustive 테스트와 정합).
public struct MemberHomeState: Equatable {
    public var member: Member?
    public var isLoading: Bool
    public var errorMessage: String?

    public init(member: Member? = nil, isLoading: Bool = false, errorMessage: String? = nil) {
        self.member = member
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }
}

public enum MemberHomeAction: Equatable {
    case load
    case loaded(Member)            // Response Action (성공)
    case loadFailed(DomainError)   // Response Action (실패)
    case tapDetail
    case tapEdit
}

/// 화면 전환 의도. `Store` 가 `observeNavigation(_:)` 으로 Coordinator 에 전달한다.
public enum MemberHomeNav: Equatable, Sendable {
    case goToDetail(MemberID)
    case presentEdit
}

public typealias MemberHomeStore = Store<MemberHomeState, MemberHomeAction, MemberHomeNav>

/// 순수 reduce. 의존성(UseCase)은 `Effect.run` 안에서만 사용하고 시그니처는 순수하게 유지한다.
public func memberHomeReducer(
    useCase: FetchMemberUseCase,
    id: MemberID
) -> (inout MemberHomeState, MemberHomeAction) -> Effect<MemberHomeAction, MemberHomeNav> {
    { state, action in
        switch action {
        case .load:
            state.isLoading = true
            state.errorMessage = nil
            return .run { send in
                do {
                    let member = try await useCase.execute(id: id)
                    send(.loaded(member))
                } catch let error as DomainError {
                    send(.loadFailed(error))
                } catch {
                    send(.loadFailed(.unknown))
                }
            }
        case .loaded(let member):
            state.member = member
            state.isLoading = false
            return .none
        case .loadFailed(let error):
            state.isLoading = false
            state.errorMessage = "\(error)"
            return .none
        case .tapDetail:
            guard let id = state.member?.id else { return .none }
            return .navigate(.goToDetail(id))
        case .tapEdit:
            return .navigate(.presentEdit)
        }
    }
}
