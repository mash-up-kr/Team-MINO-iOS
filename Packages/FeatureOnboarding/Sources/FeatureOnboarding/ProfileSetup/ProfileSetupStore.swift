import Core
import Foundation
import MVI

// [Convention] .claude/docs/mvi-coordinator-di.md 5절 — 화면 = Store 1개 = 폴더 1개, State/Action/Nav/reducer 한 파일
/// 이름 최소 길이. 화면이 안내 문구로 보여주는 값과 저장 활성 판정이 어긋나지 않도록 한 곳에서만 정의한다
/// (`ProfileSetupContent` 가 같은 값을 읽는다).
enum ProfileSetupLimit {
    static let minimumNameLength = 2
}

struct ProfileSetupState: Equatable {
    var name: String
    var selectedCharacterIndex: Int?

    init(name: String = "", selectedCharacterIndex: Int? = nil) {
        self.name = name
        self.selectedCharacterIndex = selectedCharacterIndex
    }

    /// 이름이 규칙을 지키는가 — 최소 길이와 허용 문자 둘 다.
    var isNameValid: Bool {
        name.trimmed.count >= ProfileSetupLimit.minimumNameLength
            && name.unicodeScalars.allSatisfy(Self.allowedNameScalars.contains)
    }

    /// 에러로 그릴지 판정. 비어 있으면 아직 아무것도 틀리지 않았다 — 화면에 처음 들어왔을 때
    /// 빨간 테두리가 떠 있으면 안 되므로 빈 입력은 규칙 위반으로 치지 않는다.
    var shouldShowNameError: Bool {
        !name.trimmed.isEmpty && !isNameValid
    }

    /// 저장 활성 — Figma `010` 스펙 5번 "'이름 또는 닉네임' 정상 입력 시 활성화".
    var isSaveEnabled: Bool {
        isNameValid
    }

    /// 지울 것이 있으면 지울 수 있다 — 스펙 4번이 "클릭 시 1, 2 초기화"라 캐릭터만 골라도 지울 게 있다.
    ///
    /// > 시안(010-3)은 오류 입력일 때 지우기도 회색으로 그려 저장과 같은 상태로 보이지만, 그러면
    /// > 잘못 친 이름을 지우기로 되돌릴 수 없다(필드 안 × 버튼으로만 가능). 되돌릴 대상이 있으면
    /// > 열어두는 쪽을 택했다 — 의도적인 차이다.
    var isClearEnabled: Bool {
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

enum ProfileSetupAction: Equatable {
    case nameChanged(String)
    case selectCharacter(Int)
    case tapClear
    case tapSave
}

/// 목적지가 아니라 일어난 일로 이름 붙인다 — 저장 뒤 어디로 갈지는 진입 경로마다 다르다
/// (일반 온보딩은 공동방 생성으로, 초대로 들어왔으면 튜토리얼로 간다).
enum ProfileSetupNav: Equatable, Sendable {
    case didSave
}

typealias ProfileSetupStore = Store<ProfileSetupState, ProfileSetupAction, ProfileSetupNav>

func profileSetupReducer() -> (inout ProfileSetupState, ProfileSetupAction) -> Effect<ProfileSetupAction, ProfileSetupNav> {
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
