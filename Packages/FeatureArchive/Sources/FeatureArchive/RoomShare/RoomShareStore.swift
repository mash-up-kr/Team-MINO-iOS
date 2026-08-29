import Domain
import MVI

/// 다른 방에 공유 시트(Figma `004-2-2`, 기획 011-1) 상태.
///
/// 시트가 자기 Store 를 갖는 이유: 방 목록을 비동기로 받아오고, 저장이 성공·실패로 갈리며,
/// 저장 중에는 선택을 잠가야 한다. 의존성(UseCase)은 `Effect.run` 안에서만 쓸 수 있으므로
/// `@State` 로는 이 셋을 함께 표현할 수 없다.
struct RoomShareState: Equatable {
    /// 공유하려는 장소. 저장 요청이 이 id 로 나간다.
    let pinID: PinID
    var rooms: [RoomShareRoom] = []
    /// 이 장소가 **이미 들어 있는** 방. 체크된 채 비활성이고 `selection` 과 섞지 않는다 —
    /// 섞으면 "이미 저장된 방만 있는" 상태에서 공유 버튼이 켜진다(기획 011-1 ④).
    var alreadySavedRoomIDs: Set<String> = []
    /// 사용자가 이번에 새로 고른 방.
    var selection = RoomShareSelection()
    var isLoading = false
    var isSaving = false
    /// TODO: 실패 UI 미정(백엔드 미연동) — 재시도·스낵바 정책이 정해지면 붙인다.
    ///   지금은 실패를 흘리지 않고 state 에 남겨 두기만 한다.
    var error: DomainError?

    var canSubmit: Bool { selection.canSubmit && !isSaving }

    /// 체크로 보이는 방 — 이미 저장된 방도 체크 상태다(기획 011-1 ④).
    var checkedRoomIDs: Set<String> { alreadySavedRoomIDs.union(selection.ids) }
}

enum RoomShareAction: Equatable {
    case load
    case loaded([ShareTarget])   // Response Action (성공)
    case loadFailed(DomainError)  // Response Action (실패)
    case toggleRoom(String)
    /// "새 방 만들기" 를 눌렀다 (기획 011-1 ③).
    case tapCreateRoom
    /// 공동방 만들기에서 돌아왔다. 만들었는지 아닌지에 따라 할 일이 갈린다.
    case createRoomFinished(RoomShareCreateRoomResult)
    case tapSubmit
    case saveFinished
    case saveFailed(DomainError)
}

enum RoomShareNav: Equatable, Sendable {
    /// 저장이 **실제로** 끝났다. 시트를 닫고 완료 토스트를 띄우는 신호 —
    /// X 로 닫거나 저장에 실패하면 발생하지 않는다.
    case didSave
    /// 공동방 만들기로. 시트를 **닫지 않고** 그 위에 덮는다 —
    /// 닫았다 다시 열면 고르던 방 선택이 사라진다(기획 011-1 ③).
    case goToCreateRoom
}

typealias RoomShareStore = Store<RoomShareState, RoomShareAction, RoomShareNav>

/// 순수 reduce. 의존성(UseCase)은 `Effect.run` 안에서만 사용한다.
func roomShareReducer(
    fetchTargets: FetchShareTargetsUseCase,
    savePin: SavePinToRoomsUseCase
) -> (inout RoomShareState, RoomShareAction) -> Effect<RoomShareAction, RoomShareNav> {
    /// 방 목록 조회. 진입(`.load`)과 새 방을 만들고 돌아왔을 때가 같은 경로를 쓴다 —
    /// 둘로 나누면 한쪽만 고쳐져 같은 화면이 두 목록을 갖게 된다.
    func loadTargets(_ state: inout RoomShareState) -> Effect<RoomShareAction, RoomShareNav> {
        state.isLoading = true
        let pinID = state.pinID
        return .run { send in
            do {
                send(.loaded(try await fetchTargets.execute(pinID: pinID)))
            } catch is CancellationError {
                return   // 시트를 닫아 취소된 것 — 결과가 없는 게 아니라 필요 없어진 것이다
            } catch {
                send(.loadFailed(error as? DomainError ?? .unknown))
            }
        }
    }

    return { state, action in
        switch action {
        case .load:
            return loadTargets(&state)

        case .loaded(let targets):
            state.isLoading = false
            state.rooms = targets.map { RoomShareRoom(from: $0.room) }
            state.alreadySavedRoomIDs = Set(targets.filter(\.alreadySaved).map(\.room.id))
            return .none

        case .loadFailed(let error):
            state.isLoading = false
            state.error = error
            return .none

        case .toggleRoom(let roomID):
            // 저장 중에는 선택을 잠근다 — 진행 중인 요청이 담고 있는 방 집합과 화면이 갈라진다.
            guard !state.isSaving else { return .none }
            // 이미 저장된 방은 끌 수 없다. 뷰가 비활성으로 그리지만 뷰를 고치면 뚫린다.
            guard !state.alreadySavedRoomIDs.contains(roomID) else { return .none }
            state.selection.toggle(roomID)
            return .none

        case .tapCreateRoom:
            // 저장 중에는 나가지 않는다. 저장이 끝나면 시트가 닫히는데(`didSave`), 그때 시트 위에
            // 커버가 떠 있으면 닫힌 시트 위에 방 만들기만 남는다.
            guard !state.isSaving else { return .none }
            return .navigate(.goToCreateRoom)

        case .createRoomFinished(let result):
            // 취소로 돌아왔으면 목록은 그대로다 — 같은 목록을 다시 받지 않는다.
            guard result == .created else { return .none }
            // `selection` 은 건드리지 않는다. 방을 만들러 다녀온 사이 고르던 체크가 풀리면
            // 사용자는 처음부터 다시 골라야 한다(기획 011-1 ③ "다시 011-1 화면으로 돌아온다").
            return loadTargets(&state)

        case .tapSubmit:
            // 뷰의 버튼 비활성은 UI 레이어 방어라 뷰가 바뀌면 뚫린다 — 조건은 여기서도 지킨다.
            guard state.canSubmit else { return .none }
            state.isSaving = true
            let pinID = state.pinID
            let roomIDs = state.selection.ids
            return .run { send in
                do {
                    try await savePin.execute(pinID: pinID, roomIDs: roomIDs)
                    send(.saveFinished)
                } catch is CancellationError {
                    return
                } catch {
                    send(.saveFailed(error as? DomainError ?? .unknown))
                }
            }

        case .saveFinished:
            state.isSaving = false
            return .navigate(.didSave)

        case .saveFailed(let error):
            // 시트를 저장 전 상태로 되돌려 다시 시도할 수 있게 한다. 완료 토스트는 뜨지 않는다.
            state.isSaving = false
            state.error = error
            return .none
        }
    }
}
