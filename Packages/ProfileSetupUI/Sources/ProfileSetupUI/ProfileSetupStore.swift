import Domain
import Foundation
import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
/// 이름 최소 길이. 화면이 안내 문구로 보여주는 값과 저장 활성 판정이 어긋나지 않도록 한 곳에서만 정의한다
/// (`ProfileSetupContent` 가 같은 값을 읽는다).
public enum ProfileSetupLimit {
    public static let minimumNameLength = 2
}

/// 이 화면에 무엇을 하러 들어왔는가. State 에 담기는 **순수 값**이다.
public enum ProfileSetupMode: Equatable, Sendable {
    /// 온보딩 최초 진입 — 빈 값에서 시작한다. 저장은 유저 등록.
    case create
    /// 마이페이지에서 프로필 수정 — 진입하면서 조회해 채운다. 저장은 프로필 수정.
    case edit
}

/// 진입 목적과 **그 목적에 필요한 UseCase 를 함께** 담는다.
///
/// UseCase 는 `Equatable` 이 아니라 State 에 넣을 수 없으므로 State 의 ``ProfileSetupMode`` 와 나눠 둔다.
/// 둘이 어긋나지 않게 Store 는 ``makeProfileSetupStore(_:)`` 로만 만든다.
///
/// > 모드마다 자기 UseCase 만 든다 — 셋을 평평하게 받으면 `.create` 인데 `update` 가 주입된 조합이
/// > 그냥 컴파일된다.
public enum ProfileSetupDeps: Sendable {
    case create(register: RegisterProfileUseCase)
    case edit(fetch: FetchProfileUseCase, update: UpdateProfileUseCase)

    public var mode: ProfileSetupMode {
        switch self {
        case .create: .create
        case .edit: .edit
        }
    }
}

public struct ProfileSetupState: Equatable {
    public let mode: ProfileSetupMode
    public var name: String
    public var selectedCharacterIndex: Int?
    /// `edit` 진입 조회 중. 이 동안에는 화면 대신 로딩을 그린다.
    public var isLoading: Bool
    /// 저장(등록·수정) 중. 두 번 눌러 두 번 보내는 걸 막는다.
    public var isSaving: Bool
    /// 조회 실패. **아직 화면이 읽지 않는다** — `edit` 진입점(마이페이지)이 붙을 때
    /// 재시도 UI 와 함께 연결한다. 그때까지 조회가 실패하면 빈 폼이 뜬다.
    public var loadError: DomainError?
    /// 저장 실패.
    public var saveError: DomainError?

    /// - Parameters:
    ///   - mode: 진입 목적. 기본은 온보딩(`create`).
    ///   - name: 초기 이름. `edit` 는 진입하면서 조회해 덮어쓴다.
    ///   - selectedCharacterIndex: 초기 캐릭터. 위와 같다.
    public init(
        mode: ProfileSetupMode = .create,
        name: String = "",
        selectedCharacterIndex: Int? = nil
    ) {
        self.mode = mode
        self.name = name
        self.selectedCharacterIndex = selectedCharacterIndex
        // edit 는 조회가 끝나야 보여줄 게 생긴다 — 첫 프레임부터 로딩으로 시작한다.
        self.isLoading = mode == .edit
        self.isSaving = false
        self.loadError = nil
        self.saveError = nil
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 최소 길이를 넘는가.
    private var isLongEnough: Bool {
        trimmedName.count >= ProfileSetupLimit.minimumNameLength
    }

    /// 길이와 허용 문자를 함께 본다. 어느 집합을 쓰느냐로 "입력 중"과 "저장 가능"이 갈린다.
    private func isAcceptable(_ allowed: CharacterSet) -> Bool {
        isLongEnough && name.unicodeScalars.allSatisfy(allowed.contains)
    }

    /// 에러로 그릴지 판정 — **입력 중 기준이라 자모를 봐준다.**
    /// 비어 있으면 아직 아무것도 틀리지 않았다(진입 직후 빨간 테두리 금지).
    public var shouldShowNameError: Bool {
        !trimmedName.isEmpty && !isAcceptable(Self.typingScalars)
    }

    /// 저장 활성 — Figma `010` 스펙 5번 "'이름 또는 닉네임' 정상 입력 시 활성화".
    ///
    /// **입력 중 기준보다 엄격하다.** 서버는 완성형만 받는다 — 자모를 보내면
    /// `400 VALIDATION_ERROR`(실측). 조합이 덜 끝난 상태에서는 버튼을 잠가 실패할 요청이
    /// 아예 나가지 않게 한다. 보내는 중에도 다시 못 누르게 막는다.
    public var isSaveEnabled: Bool {
        isAcceptable(Self.submittableScalars) && !isSaving
    }

    /// 지울 것이 있으면 지울 수 있다 — 스펙 4번이 "클릭 시 1, 2 초기화"라 캐릭터만 골라도 지울 게 있다.
    ///
    /// > 시안(010-3)은 오류 입력일 때 지우기도 회색으로 그려 저장과 같은 상태로 보이지만, 그러면
    /// > 잘못 친 이름을 지우기로 되돌릴 수 없다(필드 안 × 버튼으로만 가능). 되돌릴 대상이 있으면
    /// > 열어두는 쪽을 택했다 — 의도적인 차이다.
    public var isClearEnabled: Bool {
        (!name.isEmpty || selectedCharacterIndex != nil) && !isSaving
    }

    /// 서버로 보낼 아바타 자리. 아무것도 안 골랐으면 첫 캐릭터로 본다 — 화면이 무선택일 때도
    /// 1번 캐릭터를 미리보기에 띄우므로(시안 010-1), 그대로 저장되는 게 사용자가 본 것과 같다.
    var avatarIndexToSave: Int {
        selectedCharacterIndex ?? 0
    }

    /// **서버에 보낼 수 있는** 문자 — 한글 완성형·영문·공백. 방 이름과 달리 숫자를 허용하지 않는다.
    ///
    /// 서버 규칙과 같은 집합이다. 자모를 보내면 `400 VALIDATION_ERROR`
    /// ("닉네임은 한글/영문(공백 포함)만 사용할 수 있습니다") 가 온다 — 실측으로 확인했다.
    /// `CharacterSet.alphanumerics` 를 쓰지 않는 건 그게 일본어·키릴까지 통과시키기 때문.
    private static let submittableScalars: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "a"..."z")
        set.insert(charactersIn: "A"..."Z")
        set.insert(charactersIn: "\u{AC00}"..."\u{D7A3}")   // 한글 완성형
        set.insert(" ")
        return set
    }()

    /// **입력 중** 허용 문자 — 보낼 수 있는 집합에 자모를 더한 것.
    ///
    /// 조합 중간 상태(`ㄱ`, `ㅏ`)가 잠깐 state 로 들어오는데 이걸 에러로 치면 한글을 치는 내내
    /// 빨간 테두리가 깜빡인다. 그래서 **보여주는 기준만 느슨하게** 두고, 저장은
    /// ``submittableScalars`` 로 막는다 — 조합이 끝나면 버튼이 저절로 열린다.
    private static let typingScalars: CharacterSet = {
        var set = submittableScalars
        set.insert(charactersIn: "\u{3131}"..."\u{318E}")   // 호환 자모
        set.insert(charactersIn: "\u{1100}"..."\u{11FF}")   // 조합형 자모
        return set
    }()
}

public enum ProfileSetupAction: Equatable {
    /// 화면 진입. `edit` 면 여기서 조회를 시작한다.
    case task
    case loaded(Profile)
    case loadFailed(DomainError)
    case nameChanged(String)
    case selectCharacter(Int)
    case tapClear
    case tapSave
    case saveSucceeded
    case saveFailed(DomainError)
    /// 실패 안내를 닫는다 — 화면이 잠깐 띄웠다 스스로 거둔다.
    case dismissSaveError
}

/// 목적지가 아니라 일어난 일로 이름 붙인다 — 저장 뒤 어디로 갈지는 진입점마다 다르다
/// (온보딩은 공동방 생성으로, 마이페이지는 왔던 화면으로 돌아간다).
public enum ProfileSetupNav: Equatable, Sendable {
    case didSave
}

public typealias ProfileSetupStore = Store<ProfileSetupState, ProfileSetupAction, ProfileSetupNav>

/// 진입 목적과 State 가 어긋날 수 없게 Store 를 한 번에 만든다.
///
/// ```swift
/// let store = makeProfileSetupStore(.edit(fetch: deps.fetchProfile, update: deps.updateProfile))
/// store.observeNavigation { [weak self] in self?.handle($0) }   // 필수
/// ```
@MainActor
public func makeProfileSetupStore(_ deps: ProfileSetupDeps) -> ProfileSetupStore {
    ProfileSetupStore(ProfileSetupState(mode: deps.mode), reduce: profileSetupReducer(deps))
}

public func profileSetupReducer(
    _ deps: ProfileSetupDeps
) -> (inout ProfileSetupState, ProfileSetupAction) -> Effect<ProfileSetupAction, ProfileSetupNav> {
    { state, action in
        switch action {
        case .task:
            // create 는 빈 화면에서 시작한다 — 불러올 게 없다.
            guard case .edit(let fetch, _) = deps else { return .none }
            state.isLoading = true
            state.loadError = nil
            return .run { send in
                do { send(.loaded(try await fetch.execute())) }
                catch { send(.loadFailed(error as? DomainError ?? .profileFetchFailed)) }
            }

        case .loaded(let profile):
            state.isLoading = false
            state.name = profile.nickname
            state.selectedCharacterIndex = profile.avatarIndex
            return .none

        case .loadFailed(let error):
            state.isLoading = false
            state.loadError = error
            return .none

        case .nameChanged(let name):
            state.name = name
            return .none

        case .selectCharacter(let index):
            state.selectedCharacterIndex = index
            return .none

        case .tapClear:
            // 스펙 4번 "클릭 시 1, 2 초기화" — 이름과 캐릭터 선택을 함께 되돌린다.
            state.name = ""
            state.selectedCharacterIndex = nil
            return .none

        case .tapSave:
            // 뷰의 .disabled 는 UI 레이어 방어라 뷰가 바뀌면 뚫린다 — 전환 조건은 여기서도 지킨다.
            guard state.isSaveEnabled else { return .none }
            state.isSaving = true
            state.saveError = nil
            let nickname = state.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let avatarIndex = state.avatarIndexToSave
            return .run { send in
                do {
                    switch deps {
                    case .create(let register):
                        _ = try await register.execute(nickname: nickname, avatarIndex: avatarIndex)
                    case .edit(_, let update):
                        _ = try await update.execute(nickname: nickname, avatarIndex: avatarIndex)
                    }
                    send(.saveSucceeded)
                } catch {
                    send(.saveFailed(error as? DomainError ?? .profileSaveFailed))
                }
            }

        case .saveSucceeded:
            state.isSaving = false
            return .navigate(.didSave)

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
