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

    /// 편집으로 열 때는 기존 방 값을 그대로 넣어 연다.
    ///
    /// > 색은 **인덱스**로 받는다. `Room.color` 는 hex 인데 hex → 인덱스 역매핑이 아직 없다
    /// > (`MHRoomThumbnail` 의 표는 hex → enum 단방향). 편집 진입점을 붙이는 PR 에서 함께 만든다.
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
    }

    /// 방 이름이 규칙을 지키는가 — 길이 상한과 허용 문자 둘 다. 어기면 화면이 에러 상태로 그린다.
    public var isNameValid: Bool {
        roomName.count <= RoomFormLimit.name
            && roomName.unicodeScalars.allSatisfy(Self.allowedNameScalars.contains)
    }

    /// 방 설명이 규칙을 지키는가 — 상한 길이만 본다(문자 제한 없음).
    public var isDescriptionValid: Bool {
        roomDescription.count <= RoomFormLimit.description
    }

    /// 공백만 있는 이름은 확정 비활성. 상한 초과·형식 오류도 막는다 —
    /// 디자인 ⑤ "방 이름을 오류 입력 시 3·4번을 입력하더라도 비활성화 상태 유지".
    public var isSubmitEnabled: Bool {
        !roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && isNameValid
            && isDescriptionValid
    }

    /// 방 이름 허용 문자 — 한글·영문·숫자·공백.
    ///
    /// 한글은 완성형(가–힣)만이 아니라 **자모까지 허용**한다. 조합 중간 상태(`ㄱ`, `ㅏ`)가 잠깐
    /// state 로 들어오는데 이걸 막으면 한글을 치는 내내 에러 테두리가 깜빡인다.
    /// `CharacterSet.alphanumerics` 를 쓰지 않는 건 그게 일본어·키릴까지 통과시키기 때문.
    private static let allowedNameScalars: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "a"..."z")
        set.insert(charactersIn: "A"..."Z")
        set.insert(charactersIn: "0"..."9")
        set.insert(charactersIn: "\u{AC00}"..."\u{D7A3}")   // 한글 완성형
        set.insert(charactersIn: "\u{3131}"..."\u{318E}")   // 호환 자모 — iOS 조합 중간 상태
        set.insert(charactersIn: "\u{1100}"..."\u{11FF}")   // 조합형 자모
        set.insert(" ")
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
}

/// 목적지가 아니라 **일어난 일**로 이름 붙인다 — 이 화면은 온보딩과 방리스트가 함께 쓰는데
/// 방 생성 뒤 어디로 갈지는 진입점마다 다르다. `goToInviteFriends` 처럼 목적지를 박으면
/// 다른 곳으로 보내는 소비자에서 이름이 거짓말이 된다.
public enum RoomFormNav: Equatable, Sendable {
    /// 사용자가 폼을 확정했다. 만든 건지 고친 건지는 store 를 만든 쪽이 mode 로 이미 안다.
    case didSubmit
    /// 사용자가 폼을 그만뒀다. 생성 모드에서는 확인 다이얼로그의 "나가기" 를 거친 결과다.
    case didCancel
    case didSkip
}

public typealias RoomFormStore = Store<RoomFormState, RoomFormAction, RoomFormNav>

/// 입력 길이 상한. 검증(`RoomFormState`)·안내 문구·카운터가 같은 값을 읽어야 하므로 한 곳에서만 정의한다.
public enum RoomFormLimit {
    public static let name = 15
    public static let description = 30
}

public func roomFormReducer() -> (inout RoomFormState, RoomFormAction) -> Effect<RoomFormAction, RoomFormNav> {
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
        // 생성 모드에서 CTA·뒤로가기는 곧장 전환하지 않고 확인 다이얼로그를 먼저 띄운다(디자인 ⑤⑦).
        // 편집 모드는 그대로 전환한다 — 편집 화면(004-5-3)에는 확인 모달 시안이 없다.
        case .tapSubmit:
            // 뷰의 .disabled 는 UI 레이어 방어라 뷰가 바뀌면 뚫린다 — 전환 조건은 여기서도 지킨다.
            // (.tapSkip 은 건너뛰기라 조건 없이 통과한다)
            guard state.isSubmitEnabled else { return .none }
            guard state.mode == .create else { return .navigate(.didSubmit) }
            state.dialog = .saveConfirm
            return .none
        // 생성 모드는 입력이 비어 있어도 묻는다 — 디자인 ⑦ 에 조건이 없다.
        case .tapBack:
            guard state.mode == .create else { return .navigate(.didCancel) }
            state.dialog = .cancelConfirm
            return .none
        case .confirmSubmit:
            state.dialog = nil
            return .navigate(.didSubmit)
        case .confirmCancel:
            state.dialog = nil
            return .navigate(.didCancel)
        case .dismissDialog:
            state.dialog = nil
            return .none
        case .tapSkip:
            return .navigate(.didSkip)
        }
    }
}
