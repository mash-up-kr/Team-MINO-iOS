import Foundation
import MVI
import SavePostUI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일

/// 공유로 들어온 링크의 표시 정보.
///
/// 링크 분석 API 가 없어 URL 에서 유도한다. 서버가 장소명·주소·썸네일을 주기 시작하면
/// 필드가 늘고 `init(url:)` 자리가 응답 매핑으로 바뀐다 — 화면은 그대로 둔다.
public struct SharedLinkPreview: Equatable, Sendable {
    public let url: URL
    public let title: String
    public let subtitle: String

    public init(url: URL) {
        self.url = url
        self.title = url.host() ?? url.absoluteString
        self.subtitle = url.absoluteString
    }
}

/// 방 목록의 적재 상태.
///
/// 평탄한 `rooms + isLoading + error` 대신 enum 을 쓴다 — 이 화면은 세 상태에서 **그리는 것이
/// 통째로 다르고**(시트 없음 / 시트 / 스낵바 후 종료), 평탄하게 두면 "로딩 중인데 실패"처럼
/// 있을 수 없는 조합이 타입으로 허용된다.
public enum SaveLinkRooms: Equatable {
    case loading
    case loaded([SavePostRoom])
    case failed
}

/// reduce 가 쓰는 바깥 작업.
///
/// 규약(문서 5절 체크리스트)은 "reduce 는 UseCase 를 받는다"인데, `ShareExtensionUI` 는 공용 UI
/// 레이어라 `Domain` 을 알지 않는다. UseCase → 클로저 변환은 익스텐션 조립부가 맡는다
/// (`ShareExtensionDependencies`).
public struct SaveLinkDependencies: Sendable {
    /// 저장할 수 있는 방 목록.
    public var loadRooms: @Sendable () async throws -> [SavePostRoom]
    /// 고른 방들에 링크를 저장한다. 하나라도 실패하면 던진다.
    public var save: @Sendable (URL, Set<String>) async throws -> Void
    /// 저장 완료 피드백을 화면에 띄워두는 시간.
    public var holdCompletion: @Sendable () async -> Void

    public init(
        loadRooms: @escaping @Sendable () async throws -> [SavePostRoom],
        save: @escaping @Sendable (URL, Set<String>) async throws -> Void,
        holdCompletion: @escaping @Sendable () async -> Void
    ) {
        self.loadRooms = loadRooms
        self.save = save
        self.holdCompletion = holdCompletion
    }
}

public struct SaveLinkState: Equatable {
    public var link: SharedLinkPreview
    public var rooms: SaveLinkRooms = .loading
    /// 이 링크가 이미 들어 있는 방. 체크된 채 비활성이고 `selectedRoomIDs` 와 섞이지 않는다 —
    /// 섞으면 "이미 저장된 방만 있는" 상태에서 저장 버튼이 켜진다(Figma 013-1-2 는 비활성).
    ///
    /// > 지금은 항상 비어 있다. 판별하려면 링크가 이미 장소로 추출돼 `placeId` 가 있어야 하는데
    /// > (`GET /rooms` 의 `showHasPlaceId`), 공유 시점의 링크는 아직 추출 전이다.
    public var savedRoomIDs: Set<String>
    public var selectedRoomIDs: Set<String> = []
    public var isSaving = false
    public var isSaved = false
    /// 저장이 실패했다. 시트는 남기고 스낵바만 띄운다 — 다시 누를 수 있어야 한다.
    public var saveFailed = false

    public init(link: SharedLinkPreview, savedRoomIDs: Set<String> = []) {
        self.link = link
        self.savedRoomIDs = savedRoomIDs
    }

    public var loadedRooms: [SavePostRoom] {
        if case .loaded(let rooms) = rooms { return rooms }
        return []
    }

    public var canSubmit: Bool { !selectedRoomIDs.isEmpty && !isSaving && !isSaved }

    /// 체크로 보이는 방 — 이미 저장된 방도 체크 상태다(Figma 스펙 시트 2번).
    public var checkedRoomIDs: Set<String> { savedRoomIDs.union(selectedRoomIDs) }
}

public enum SaveLinkAction: Equatable {
    /// 진입 로드.
    case task
    case roomsLoaded([SavePostRoom])
    case roomsLoadFailed
    case toggleRoom(String)
    case tapSave
    case saveSucceeded
    case saveFailed
    /// 완료 피드백을 충분히 보여줌.
    case completionShown
    case tapClose
}

/// 목적지가 아니라 일어난 일로 이름 붙인다 — 익스텐션은 화면을 옮기는 게 아니라 자기를 끝낸다.
public enum SaveLinkNav: Equatable, Sendable {
    case dismiss
}

public typealias SaveLinkStore = Store<SaveLinkState, SaveLinkAction, SaveLinkNav>

public func saveLinkReducer(
    _ dependencies: SaveLinkDependencies
) -> (inout SaveLinkState, SaveLinkAction) -> Effect<SaveLinkAction, SaveLinkNav> {
    { state, action in
        switch action {
        case .task:
            // View 의 `.task` 는 재부착 때 다시 불릴 수 있다 — 이미 받아온 목록을 로딩으로 되돌리지 않는다.
            guard case .loading = state.rooms else { return .none }
            return .run { send in
                do {
                    send(.roomsLoaded(try await dependencies.loadRooms()))
                } catch is CancellationError {
                    // 취소는 결과가 없는 것이지 실패가 아니다 — 익스텐션이 닫히는 중이라 그릴 화면도 없다.
                    return
                } catch {
                    send(.roomsLoadFailed)
                }
            }

        case .roomsLoaded(let rooms):
            state.rooms = .loaded(rooms)
            return .none

        case .roomsLoadFailed:
            state.rooms = .failed
            return .none

        case .toggleRoom(let id):
            // 저장이 시작된 뒤 선택이 바뀌면 화면과 실제 저장 대상이 어긋난다.
            guard !state.isSaving, !state.isSaved else { return .none }
            // 이미 저장된 방은 끌 수 없다 — 뷰가 체크박스를 비활성으로 그리지만, 뷰를 고치면 뚫린다.
            guard !state.savedRoomIDs.contains(id) else { return .none }
            if state.selectedRoomIDs.contains(id) {
                state.selectedRoomIDs.remove(id)
            } else {
                state.selectedRoomIDs.insert(id)
            }
            return .none

        case .tapSave:
            // 뷰의 비활성 처리는 UI 레이어 방어라 뷰가 바뀌면 뚫린다 — 조건은 여기서도 지킨다.
            guard state.canSubmit else { return .none }
            state.isSaving = true
            state.saveFailed = false
            let url = state.link.url
            let ids = state.selectedRoomIDs
            return .run { send in
                do {
                    try await dependencies.save(url, ids)
                    send(.saveSucceeded)
                } catch is CancellationError {
                    return
                } catch {
                    send(.saveFailed)
                }
            }

        case .saveSucceeded:
            guard state.isSaving else { return .none }
            state.isSaving = false
            state.isSaved = true
            return .run { send in
                await dependencies.holdCompletion()
                send(.completionShown)
            }

        case .saveFailed:
            guard state.isSaving else { return .none }
            state.isSaving = false
            state.saveFailed = true
            return .none

        case .completionShown:
            guard state.isSaved else { return .none }
            return .navigate(.dismiss)

        case .tapClose:
            // 저장 중에는 닫지 않는다 — 닫기는 익스텐션 종료(completeRequest)로 이어져
            // 진행 중인 저장 Task 가 잘린다.
            guard !state.isSaving else { return .none }
            return .navigate(.dismiss)
        }
    }
}
