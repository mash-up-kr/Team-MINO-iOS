import Core
import Foundation
import MVI

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

/// reduce 가 쓰는 바깥 작업.
///
/// 규약(문서 5절 체크리스트)은 "reduce 는 UseCase 를 받는다"인데, 저장 API 도 도메인도 아직 없어
/// 만들 UseCase 가 없다. 클로저로 열어두고 API 가 붙는 PR 에서 UseCase 주입으로 바꾼다 —
/// State/Action/View 는 그대로 간다.
public struct SaveLinkDependencies: Sendable {
    /// 고른 방들에 링크를 저장한다.
    public var save: @Sendable (SharedLinkPreview, Set<String>) async -> Void
    /// 저장 완료 피드백을 화면에 띄워두는 시간.
    public var holdCompletion: @Sendable () async -> Void

    public init(
        save: @escaping @Sendable (SharedLinkPreview, Set<String>) async -> Void,
        holdCompletion: @escaping @Sendable () async -> Void
    ) {
        self.save = save
        self.holdCompletion = holdCompletion
    }

    /// 백엔드 미연결 단계용. 저장은 하지 않고 완료 피드백만 잠깐 보여준다.
    public static let stub = SaveLinkDependencies(
        save: { _, _ in },
        holdCompletion: { try? await Task.sleep(for: .seconds(1.2)) }
    )
}

public struct SaveLinkState: Equatable {
    public var link: SharedLinkPreview
    public var rooms: [SharedRoom]
    /// 이 링크가 이미 들어 있는 방. 체크된 채 비활성이고 `selectedRoomIDs` 와 섞이지 않는다 —
    /// 섞으면 "이미 저장된 방만 있는" 상태에서 저장 버튼이 켜진다(Figma 013-1-2 는 비활성).
    public var savedRoomIDs: Set<String>
    public var selectedRoomIDs: Set<String> = []
    public var isSaving = false
    public var isSaved = false

    public init(link: SharedLinkPreview, rooms: [SharedRoom], savedRoomIDs: Set<String> = []) {
        self.link = link
        self.rooms = rooms
        self.savedRoomIDs = savedRoomIDs
    }

    public var canSubmit: Bool { !selectedRoomIDs.isEmpty && !isSaving && !isSaved }

    /// 체크로 보이는 방 — 이미 저장된 방도 체크 상태다(Figma 스펙 시트 2번).
    public var checkedRoomIDs: Set<String> { savedRoomIDs.union(selectedRoomIDs) }
}

public enum SaveLinkAction: Equatable {
    case toggleRoom(String)
    case tapSave
    /// 저장 작업이 끝남.
    case saveFinished
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
            let link = state.link
            let ids = state.selectedRoomIDs
            return .run { send in
                await dependencies.save(link, ids)
                send(.saveFinished)
            }

        case .saveFinished:
            guard state.isSaving else { return .none }
            state.isSaving = false
            state.isSaved = true
            return .run { send in
                await dependencies.holdCompletion()
                send(.completionShown)
            }

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
