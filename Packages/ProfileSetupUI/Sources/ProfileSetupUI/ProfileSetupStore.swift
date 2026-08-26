import Foundation
import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
/// 이름 최소 길이. 화면이 안내 문구로 보여주는 값과 저장 활성 판정이 어긋나지 않도록 한 곳에서만 정의한다
/// (`ProfileSetupContent` 가 같은 값을 읽는다).
public enum ProfileSetupLimit {
    public static let minimumNameLength = 2
}

/// 이 화면에 무엇을 하러 들어왔는가. 진입점마다 초기값·저장 API·뒤로가기가 갈린다.
public enum ProfileSetupMode: Equatable, Sendable {
    /// 온보딩 최초 진입 — 빈 값에서 시작한다. 저장은 **유저 등록**.
    case create
    /// 마이페이지에서 프로필 수정 — **프로필 조회** 결과를 프리필한다. 저장은 **프로필 수정**.
    case edit
}

public extension ProfileSetupMode {
    /// 뒤로가기를 그릴지 — `create` 는 온보딩 최초 진입이라 돌아갈 곳이 없다(Figma `010` 스펙 3번).
    var showsBack: Bool { self == .edit }
}

public struct ProfileSetupState: Equatable {
    public let mode: ProfileSetupMode
    public var name: String
    public var selectedCharacterIndex: Int?

    /// - Parameters:
    ///   - mode: 진입 목적. 기본은 온보딩(`create`).
    ///   - name: 초기 이름. `edit` 는 프로필 조회 결과를 넣어 프리필한다(`create` 는 빈 값).
    ///   - selectedCharacterIndex: 초기 캐릭터. 위와 같다.
    public init(
        mode: ProfileSetupMode = .create,
        name: String = "",
        selectedCharacterIndex: Int? = nil
    ) {
        self.mode = mode
        self.name = name
        self.selectedCharacterIndex = selectedCharacterIndex
    }

    /// 이름이 규칙을 지키는가 — 최소 길이와 허용 문자 둘 다.
    public var isNameValid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= ProfileSetupLimit.minimumNameLength
            && name.unicodeScalars.allSatisfy(Self.allowedNameScalars.contains)
    }

    /// 에러로 그릴지 판정. 비어 있으면 아직 아무것도 틀리지 않았다 — 화면에 처음 들어왔을 때
    /// 빨간 테두리가 떠 있으면 안 되므로 빈 입력은 규칙 위반으로 치지 않는다.
    public var shouldShowNameError: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isNameValid
    }

    /// 저장 활성 — Figma `010` 스펙 5번 "'이름 또는 닉네임' 정상 입력 시 활성화".
    public var isSaveEnabled: Bool {
        isNameValid
    }

    /// 지울 것이 있으면 지울 수 있다 — 스펙 4번이 "클릭 시 1, 2 초기화"라 캐릭터만 골라도 지울 게 있다.
    ///
    /// > 시안(010-3)은 오류 입력일 때 지우기도 회색으로 그려 저장과 같은 상태로 보이지만, 그러면
    /// > 잘못 친 이름을 지우기로 되돌릴 수 없다(필드 안 × 버튼으로만 가능). 되돌릴 대상이 있으면
    /// > 열어두는 쪽을 택했다 — 의도적인 차이다.
    public var isClearEnabled: Bool {
        !name.isEmpty || selectedCharacterIndex != nil
    }

    /// 이름 허용 문자 — 한글·영문·공백. 방 이름과 달리 **숫자를 허용하지 않는다**(스펙 "한글·영문").
    ///
    /// 한글은 완성형(가–힣)만이 아니라 **자모까지 허용**한다. 조합 중간 상태(`ㄱ`, `ㅏ`)가 잠깐
    /// state 로 들어오는데 이걸 막으면 한글을 치는 내내 에러 테두리가 깜빡인다.
    /// `CharacterSet.alphanumerics` 를 쓰지 않는 건 그게 일본어·키릴까지 통과시키기 때문.
    private static let allowedNameScalars: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "a"..."z")
        set.insert(charactersIn: "A"..."Z")
        set.insert(charactersIn: "\u{AC00}"..."\u{D7A3}")   // 한글 완성형
        set.insert(charactersIn: "\u{3131}"..."\u{318E}")   // 호환 자모 — iOS 조합 중간 상태
        set.insert(charactersIn: "\u{1100}"..."\u{11FF}")   // 조합형 자모
        set.insert(" ")
        return set
    }()
}

public enum ProfileSetupAction: Equatable {
    case nameChanged(String)
    case selectCharacter(Int)
    case tapClear
    case tapSave
}

/// 목적지가 아니라 일어난 일로 이름 붙인다 — 저장 뒤 어디로 갈지는 진입점마다 다르다
/// (온보딩은 공동방 생성으로, 마이페이지는 왔던 화면으로 돌아간다).
public enum ProfileSetupNav: Equatable, Sendable {
    case didSave
}

public typealias ProfileSetupStore = Store<ProfileSetupState, ProfileSetupAction, ProfileSetupNav>

/// 프로필 설정 reduce.
///
/// > 저장은 아직 서버에 아무것도 보내지 않는다 — `didSave` 를 알리고 끝난다.
/// > API 를 붙일 때는 모드에 연관값을 달아 각 모드가 **자기 UseCase 만** 들게 한다:
/// >
/// > ```swift
/// > case create(register: RegisterProfileUseCase)
/// > case edit(fetch: FetchProfileUseCase, update: UpdateProfileUseCase)
/// > ```
/// >
/// > 평평하게 셋을 다 받으면 `.create` 인데 `update` 가 주입된 조합이 그냥 컴파일된다.
/// > `edit` 의 조회는 `.task` 진입 Action 에서 `.run` 으로 부르고, 성공·실패를 Response Action 으로
/// > 되돌린다(로딩 상태는 그때 State 에 함께 넣는다).
public func profileSetupReducer() -> (inout ProfileSetupState, ProfileSetupAction) -> Effect<ProfileSetupAction, ProfileSetupNav> {
    { state, action in
        switch action {
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
            return .navigate(.didSave)
        }
    }
}
