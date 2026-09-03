import Domain
import MVI

/// 상세 화면 상태 — Root 와 독립된 자기 상태(화면 단위 Store).
public struct MemberDetailState: Equatable {
    public var member: Member?
    public var isLoading: Bool
    public var errorMessage: String?

    public init(member: Member? = nil, isLoading: Bool = false, errorMessage: String? = nil) {
        self.member = member
        self.isLoading = isLoading
        self.errorMessage = errorMessage
    }
}

public enum MemberDetailAction: Equatable {
    case load
    case loaded(Member)            // Response Action (성공)
    case loadFailed(DomainError)   // Response Action (실패)
}

/// 상세 화면은 추가 화면 전환을 하지 않으므로 전환 의도가 없다(빈 enum).
/// 전환이 생기면 case 를 추가하고 Coordinator 에 `observeNavigation` 을 연결한다.
public enum MemberDetailNav: Equatable, Sendable {}

public typealias MemberDetailStore = Store<MemberDetailState, MemberDetailAction, MemberDetailNav>

/// 순수 reduce. 상세는 멤버를 로드해 표시만 한다(전환 없음).
public func memberDetailReducer(
    useCase: FetchMemberUseCase,
    id: MemberID
) -> (inout MemberDetailState, MemberDetailAction) -> Effect<MemberDetailAction, MemberDetailNav> {
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
        }
    }
}
