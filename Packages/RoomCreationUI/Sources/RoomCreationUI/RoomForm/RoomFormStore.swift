import Domain
import Foundation
import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
/// 이 폼이 무엇을 하는 중인가. 제목·CTA 문구와 확인 절차가 여기서 갈린다.
public enum RoomFormMode: Equatable, Sendable {
    /// 공동방 만들기 (디자인 001-1)
    case create
    /// 방 편집 (디자인 004-5-3, 방장만)
    case edit
}

/// 진입 목적과 **그 목적에 필요한 UseCase 를 함께** 담는다.
///
/// UseCase 는 `Equatable` 이 아니라 State 에 넣을 수 없으므로 State 의 ``RoomFormMode`` 와 나눠 둔다.
/// 둘이 어긋나지 않게 Store 는 ``makeRoomFormStore(_:handle:)`` 로만 만든다.
///
/// > 모드마다 자기 UseCase 만 든다 — 둘을 평평하게 받으면 `.create` 인데 `update` 가 주입된 조합이
/// > 그냥 컴파일된다.
public enum RoomFormDeps: Sendable {
    case create(create: CreateRoomUseCase)
    /// 편집 — 호출부가 이미 들고 있는 방을 통째로 받는다(수정 대상 id + 폼 초기값).
    case edit(room: Room, update: UpdateRoomUseCase)

    public var mode: RoomFormMode {
        switch self {
        case .create: .create
        case .edit: .edit
        }
    }
}

/// 화면 위에 떠 있는 확인 다이얼로그. 없으면 `nil`.
public enum RoomFormDialog: Equatable, Identifiable, Sendable {
    /// CTA 를 눌렀을 때 — "저장하시겠어요?" (디자인 001-1-4)
    case saveConfirm
    /// 뒤로가기를 눌렀을 때 — "만들기를 취소하시겠어요?" (디자인 001-1-4)
    case cancelConfirm

    public var id: Self { self }
}

public struct RoomFormState: Equatable {
    public let mode: RoomFormMode
    public var roomName: String
    public var roomDescription: String
    public var selectedColorIndex: Int?
    public var dialog: RoomFormDialog?
    /// 저장(생성·수정) 중. 두 번 눌러 두 번 보내는 걸 막는다.
    public var isSaving: Bool
    /// 저장 실패. 화면이 잠깐 안내를 띄웠다 거둔다.
    public var saveError: DomainError?

    /// 편집으로 열 때는 기존 방 값을 그대로 넣어 연다 — ``makeRoomFormStore(_:handle:)`` 가 채운다.
    public init(
        mode: RoomFormMode = .create,
        roomName: String = "",
        roomDescription: String = "",
        selectedColorIndex: Int? = nil
    ) {
        self.mode = mode
        self.roomName = roomName
        self.roomDescription = roomDescription
        self.selectedColorIndex = selectedColorIndex
        self.isSaving = false
        self.saveError = nil
    }

    /// 방 이름을 에러로 그릴지 — **입력 중 기준이라 자모를 봐준다.**
    /// 조합 중간 상태를 에러로 치면 한글을 치는 내내 빨간 테두리가 깜빡인다.
    public var isNameValid: Bool {
        isNameAcceptable(Self.typingScalars)
    }

    /// 방 설명이 규칙을 지키는가 — 상한 길이만 본다(문자 제한 없음).
    public var isDescriptionValid: Bool {
        roomDescription.count <= RoomFormLimit.description
    }

    /// 공백만 있는 이름은 확정 비활성. 상한 초과·형식 오류도 막는다 —
    /// 디자인 ⑤ "방 이름을 오류 입력 시 3·4번을 입력하더라도 비활성화 상태 유지".
    /// 저장 중에도 잠근다.
    ///
    /// **표시 기준(``isNameValid``)보다 엄격하다** — 조합이 덜 끝난 자모는 보내지 않는다.
    /// 조합이 끝나면 버튼이 저절로 열린다.
    public var isSubmitEnabled: Bool {
        // trimmingCharacters 는 버릴 String 을 새로 할당한다 — 첫 비공백에서 끊는 편이 싸다.
        roomName.contains { !$0.isWhitespace }
            && isNameAcceptable(Self.submittableScalars)
            && isDescriptionValid
            && !isSaving
    }

    /// 이름이 길이 상한을 지키고 주어진 문자 집합 안에 있는가.
    private func isNameAcceptable(_ allowed: CharacterSet) -> Bool {
        roomName.count <= RoomFormLimit.name
            && roomName.unicodeScalars.allSatisfy(allowed.contains)
    }

    /// 서버로 보낼 방 이름. 앞뒤 공백은 떼고 보낸다.
    var nameToSave: String {
        roomName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 서버로 보낼 설명. 비어 있으면 `null` 로 보낸다(서버가 nullable 로 받는다).
    var descriptionToSave: String? {
        let trimmed = roomDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// 서버로 보낼 색. 폼은 색 없이도 확정되므로 미선택이면 기본색으로 떨어진다.
    ///
    /// > 미리보기 썸네일은 미선택일 때 my-room 을 그려서 **본 것과 저장되는 것이 어긋난다.**
    /// > 디자인 확인 대상 — 색 선택을 필수로 할지, 미선택 미리보기를 기본색으로 바꿀지 정해야 한다.
    var colorToSave: RoomColor {
        selectedColorIndex.flatMap(RoomColorPalette.color(at:)) ?? RoomColorPalette.defaultColor
    }

    /// **서버로 보낼 수 있는** 문자 — 한글 완성형·영문·숫자·공백. 안내 문구가 약속하는 집합이다.
    ///
    /// 자모를 뺀다. 서버는 방 `name` 에 패턴을 걸지 않아 자모도 201 로 받지만(닉네임과 다르다 —
    /// `POST /api/v1/users` 의 `nickname` 만 `^[가-힣A-Za-z ]+$` 다), 조합이 덜 끝난 `ㄱ` 이
    /// 방 이름으로 굳어 목록에 남는 걸 클라이언트가 막는다.
    /// `CharacterSet.alphanumerics` 를 쓰지 않는 건 그게 일본어·키릴까지 통과시키기 때문.
    private static let submittableScalars: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "a"..."z")
        set.insert(charactersIn: "A"..."Z")
        set.insert(charactersIn: "0"..."9")
        set.insert(charactersIn: "\u{AC00}"..."\u{D7A3}")   // 한글 완성형
        set.insert(" ")
        return set
    }()

    /// **입력 중** 허용 문자 — 보낼 수 있는 집합에 자모를 더한 것.
    ///
    /// 조합 중간 상태(`ㄱ`, `ㅏ`)가 잠깐 state 로 들어오는데 이걸 에러로 치면 한글을 치는 내내
    /// 빨간 테두리가 깜빡인다. **보여주는 기준만 느슨하게** 두고 확정은 ``submittableScalars`` 로 막는다.
    private static let typingScalars: CharacterSet = {
        var set = submittableScalars
        set.insert(charactersIn: "\u{3131}"..."\u{318E}")   // 호환 자모
        set.insert(charactersIn: "\u{1100}"..."\u{11FF}")   // 조합형 자모
        return set
    }()
}

public enum RoomFormAction: Equatable {
    case roomNameChanged(String)
    case roomDescriptionChanged(String)
    case selectColor(Int)
    case tapSubmit
    case tapBack
    case confirmSubmit
    case confirmCancel
    case dismissDialog
    case tapSkip
    /// 저장이 끝났다. 만들어졌거나 고쳐진 방의 id 를 함께 나른다.
    case saveSucceeded(roomId: String)
    case saveFailed(DomainError)
    /// 실패 안내를 닫는다 — 화면이 잠깐 띄웠다 스스로 거둔다.
    case dismissSaveError
}

/// 목적지가 아니라 **일어난 일**로 이름 붙인다 — 이 화면은 온보딩과 방리스트가 함께 쓰는데
/// 방 생성 뒤 어디로 갈지는 진입점마다 다르다. `goToInviteFriends` 처럼 목적지를 박으면
/// 다른 곳으로 보내는 소비자에서 이름이 거짓말이 된다.
public enum RoomFormNav: Equatable, Sendable {
    /// 방이 서버에 저장됐다. 만든 건지 고친 건지는 store 를 만든 쪽이 mode 로 이미 안다.
    ///
    /// `Room` 통째가 아니라 id 만 나른다 — 뒤따르는 화면(친구 초대)이 필요한 게 그것뿐이고,
    /// `Sendable` 유지도 단순하다. 더 필요해지면 그때 넓힌다.
    case didSubmit(roomId: String)
    /// 사용자가 폼을 그만뒀다. 생성 모드에서는 확인 다이얼로그의 "나가기" 를 거친 결과다.
    case didCancel
    case didSkip
}

public typealias RoomFormStore = Store<RoomFormState, RoomFormAction, RoomFormNav>

/// 입력 길이 상한. 검증(`RoomFormState`)·안내 문구·카운터가 같은 값을 읽어야 하므로 한 곳에서만 정의한다.
///
/// > ⚠️ 설명 상한이 **서버(20자)와 다르다.** 21자 이상은 확정 버튼이 열린 채 저장이 400 으로
/// > 실패한다 — 어느 쪽에 맞출지 미정이라 이번에는 손대지 않았다.
public enum RoomFormLimit {
    public static let name = 15
    public static let description = 30
}

/// 진입 목적과 State 가 어긋날 수 없게 Store 를 한 번에 만든다.
///
/// `handle` 은 `Store.init(_:reduce:handle:)` 로 그대로 넘어간다 — navigation 구독 누락을
/// 구조적으로 막는 그 규칙을 이 팩토리도 따른다.
///
/// ```swift
/// makeRoomFormStore(.create(create: deps.createRoom), handle: { [weak self] in self?.handle($0) })
/// ```
@MainActor
public func makeRoomFormStore(
    _ deps: RoomFormDeps,
    handle: @escaping @MainActor (RoomFormNav) -> Void
) -> RoomFormStore {
    RoomFormStore(initialState(deps), reduce: roomFormReducer(deps), handle: handle)
}

/// 편집은 기존 방 값에서 시작한다. 폼은 색을 인덱스로 들고 있어 도메인 색을 되돌려 담는다.
private func initialState(_ deps: RoomFormDeps) -> RoomFormState {
    switch deps {
    case .create:
        RoomFormState(mode: .create)
    case .edit(let room, _):
        RoomFormState(
            mode: .edit,
            roomName: room.name,
            roomDescription: room.description ?? "",
            selectedColorIndex: room.color.flatMap(RoomColorPalette.index(of:))
        )
    }
}

public func roomFormReducer(
    _ deps: RoomFormDeps
) -> (inout RoomFormState, RoomFormAction) -> Effect<RoomFormAction, RoomFormNav> {
    { state, action in
        switch action {
        // 입력을 자르지 않고 그대로 담는다. 잘라 담으면 `count > limit` 이 영원히 성립하지 않아
        // 초과 워닝이 뜰 수 없고, 한글 조합 중에는 화면(TextField)이 잘린 state 를 따라오지 못해
        // "카운터는 20/20 인데 필드엔 60자" 처럼 어긋난다 — 사용자는 다 썼다고 믿고 생성한다.
        case .roomNameChanged(let name):
            state.roomName = name
            return .none
        case .roomDescriptionChanged(let description):
            state.roomDescription = description
            return .none
        case .selectColor(let index):
            state.selectedColorIndex = index
            return .none
        // CTA·뒤로가기는 곧장 전환하지 않고 확인 다이얼로그를 먼저 띄운다(디자인 ⑤⑦).
        // 단 편집 모드의 CTA(저장)는 그대로 저장한다 — 나가기는 변경 유실 경고가 필요하지만
        // 저장은 이미 명시적인 의도라 한 번 더 묻지 않는다.
        case .tapSubmit:
            // 뷰의 .disabled 는 UI 레이어 방어라 뷰가 바뀌면 뚫린다 — 조건은 여기서도 지킨다.
            // (.tapSkip 은 건너뛰기라 조건 없이 통과한다)
            guard state.isSubmitEnabled else { return .none }
            if state.mode == .edit { return save(&state, deps) }
            state.dialog = .saveConfirm
            return .none
        // 입력이 비어 있어도 묻는다 — 디자인 ⑦ 에 조건이 없다. 문구는 화면이 mode 로 고른다.
        case .tapBack:
            state.dialog = .cancelConfirm
            return .none
        case .confirmSubmit:
            state.dialog = nil
            return save(&state, deps)
        case .confirmCancel:
            state.dialog = nil
            return .navigate(.didCancel)
        case .dismissDialog:
            state.dialog = nil
            return .none
        case .tapSkip:
            return .navigate(.didSkip)
        // 저장이 끝나야 화면을 넘긴다 — 실패했는데 넘어가면 만들어지지 않은 방으로 이동한다.
        case .saveSucceeded(let roomId):
            state.isSaving = false
            return .navigate(.didSubmit(roomId: roomId))
        case .saveFailed(let error):
            state.isSaving = false
            state.saveError = error
            return .none
        case .dismissSaveError:
            state.saveError = nil
            return .none
        }
    }
}

/// 생성·수정 요청을 띄운다. 두 진입(`tapSubmit` 의 편집, `confirmSubmit` 의 생성)이 같은 코드를 탄다.
private func save(
    _ state: inout RoomFormState,
    _ deps: RoomFormDeps
) -> Effect<RoomFormAction, RoomFormNav> {
    state.isSaving = true
    state.saveError = nil
    let name = state.nameToSave
    let description = state.descriptionToSave
    let color = state.colorToSave

    return .run { send in
        do {
            let roomId: String
            switch deps {
            case .create(let create):
                roomId = try await create.execute(name: name, description: description, color: color).id
            case .edit(let room, let update):
                _ = try await update.execute(
                    roomId: room.id,
                    name: name,
                    description: description,
                    color: color
                )
                roomId = room.id   // 편집은 대상을 이미 안다
            }
            send(.saveSucceeded(roomId: roomId))
        } catch is CancellationError {
            // 취소는 결과가 없는 것이지 실패가 아니다 — 화면을 떠났으면 state 는 곧 버려진다.
            return
        } catch {
            send(.saveFailed(error as? DomainError ?? .roomSaveFailed))
        }
    }
}
