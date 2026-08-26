import SwiftUI
import DesignSystem

// MARK: - 캐릭터 스와치

/// 캐릭터 선택 12종. 순서는 `MHCharacter` 선언 순서 = 피그마 4열×3행 그리드(좌→우, 상→하)다.
private let characterSwatches: [MHSelectionGridItem] = MHCharacter.allCases.map { .image(Image($0)) }

// [Convention] .claude/docs/mvi-coordinator-di.md — Store·Coordinator 를 모르는 순수 마크업.
// Figma `010-1/2/3. 프로필 설정` (node 2314:95662 기본 / 2314:95709 입력 완료 / 2314:95754 입력 오류)
// — 세 상태를 값(`isSaveEnabled`·`showsNameError`)으로만 그린다.
/// 프로필 설정 화면의 마크업. 이름 입력 + 캐릭터 선택 + 저장/지우기 액션으로 구성된다.
struct ProfileSetupContent: View {
    /// 이름/닉네임 입력값. 입력 필드는 SUITE 대신 시스템 폰트를 쓴다(`MHTextField` 내부 규칙, DesignSystem README 참조).
    @Binding var name: String
    /// 선택된 캐릭터 인덱스(0~11). `nil` 이면 아직 아무 캐릭터도 고르지 않은 상태.
    let selectedCharacterIndex: Int?
    /// 이름을 에러 상태로 그릴지. 판정은 Store 몫 — 여기서는 받은 값으로만 그린다.
    let showsNameError: Bool
    /// 저장 가능 여부. 이름 유효성 등 판단은 Store 몫 — 여기서는 받은 값으로만 활성/비활성을 그린다.
    let isSaveEnabled: Bool
    /// 지우기 가능 여부. 저장과 조건이 달라 따로 받는다.
    let isClearEnabled: Bool
    let onSelectCharacter: (Int) -> Void
    let onClear: () -> Void
    let onSave: () -> Void
    /// `nil` 이면 상단바에 뒤로가기를 그리지 않는다 — 온보딩 최초 진입처럼 돌아갈 곳이 없는 진입점을 위해.
    var onBack: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            MHTopNavigation(title: "프로필 설정", onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("친구들에게 어떻게 보일까요?")
                        .mhTypography(.title3Bold)
                        .foregroundStyle(.mhPrimaryNormal)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    previewAvatar
                        .frame(maxWidth: .infinity)

                    MHTextField(
                        "한글·영문 \(ProfileSetupLimit.minimumNameLength)글자 이상",
                        text: $name,
                        heading: "이름 또는 닉네임",
                        isRequired: true,
                        description: "한글·영문 \(ProfileSetupLimit.minimumNameLength)글자 이상을 입력해주세요.",
                        status: showsNameError ? .negative : .normal,
                        identifier: "ProfileSetup.nameField"
                    )

                    characterPicker
                }
                .padding(20)
            }
            // 액션 영역을 VStack 자식으로 두면 키보드가 올라올 때 MHActionArea 의 하단 안전영역 측정에
            // 키보드 높이가 섞여 스크롤뷰가 찌그러진다. safeAreaInset 으로 붙여 키보드 회피를 맡긴다.
            .safeAreaInset(edge: .bottom) {
                // 활성 조건이 슬롯마다 달라 MHAction 의 isEnabled 로 준다.
                // 영역 전체에 .disabled 를 걸면 조건이 맞는 슬롯까지 함께 죽는다(MHAction 주석 참조).
                MHActionArea(
                    variant: .neutral,
                    main: MHAction("저장", isEnabled: isSaveEnabled, action: onSave),
                    alternative: MHAction("지우기", isEnabled: isClearEnabled, action: onClear),
                    sticky: true,
                    safeArea: false
                )
            }
        }
        .background(Color.mhBackgroundNormalNormal)
        // 키보드가 하단을 가리면 캐릭터 그리드와 저장 버튼에 손이 닿지 않는다 — 공동방 만들기와 같은
        // 두 탈출로(스크롤·여백 탭)를 건다.
        .mhFormKeyboardDismissal()
    }

    // MARK: - 큰 미리보기 원 (120x120)

    // 캐릭터 아트가 옅은 원 배경까지 포함한 이미지라 테두리를 따로 두지 않는다 —
    // 링을 얹으면 시안(010-1 Container 120×120, 테두리 없음)보다 원이 한 겹 더 생겨 보인다.
    private var previewAvatar: some View {
        Image(previewCharacter)
            .resizable()
            .scaledToFill()
            .frame(width: 120, height: 120)
            .clipShape(Circle())
            .accessibilityIdentifier("ProfileSetup.previewAvatar")
    }

    // 아무것도 안 고른 상태에서도 첫 캐릭터를 보여준다 — Figma `010-1` 기본 시안이 미리보기엔 1번 캐릭터를
    // 띄우고 그리드엔 선택 링을 안 그린 상태다. 그래서 `selectedCharacterIndex` 는 nil 로 그대로 넘긴다.
    private var previewCharacter: MHCharacter {
        guard let selectedCharacterIndex, MHCharacter.allCases.indices.contains(selectedCharacterIndex) else {
            return MHCharacter.allCases[0]
        }
        return MHCharacter.allCases[selectedCharacterIndex]
    }

    // MARK: - 캐릭터 선택 그리드

    private var characterPicker: some View {
        MHSelectionGrid(
            title: "프로필 이미지 선택",
            items: characterSwatches,
            selectedIndex: selectedCharacterIndex,
            shape: .circle,
            identifierPrefix: "ProfileSetup.character",
            onSelect: onSelectCharacter
        )
    }

}

#Preview("010-2 입력 완료") {
    ProfileSetupContentPreviewWrapper(name: "민호", selectedCharacterIndex: 11, isSaveEnabled: true)
}

#Preview("010-1 기본") {
    ProfileSetupContentPreviewWrapper(name: "", selectedCharacterIndex: nil, isSaveEnabled: false)
}

#Preview("010-3 입력 오류") {
    ProfileSetupContentPreviewWrapper(name: "민호1", selectedCharacterIndex: 11, isSaveEnabled: false, showsNameError: true)
}

// 저장은 막히고 지우기는 열리는 구간(이름 1글자) — 두 버튼이 갈리는 유일한 상태다.
#Preview("저장만 비활성") {
    ProfileSetupContentPreviewWrapper(name: "민", selectedCharacterIndex: nil, isSaveEnabled: false)
}

// 온보딩 밖(마이페이지 등)에서 재사용할 때의 모습 — 상단에 뒤로가기가 생긴다.
#Preview("뒤로가기 있음") {
    ProfileSetupContentPreviewWrapper(name: "민호", selectedCharacterIndex: 5, isSaveEnabled: true, showsBack: true)
}

// #Preview 클로저는 @State 를 직접 못 가져 바인딩용 래퍼로 감싼다.
private struct ProfileSetupContentPreviewWrapper: View {
    @State var name: String
    @State var selectedCharacterIndex: Int?
    let isSaveEnabled: Bool
    var showsNameError: Bool = false
    var showsBack: Bool = false

    var body: some View {
        ProfileSetupContent(
            name: $name,
            selectedCharacterIndex: selectedCharacterIndex,
            showsNameError: showsNameError,
            isSaveEnabled: isSaveEnabled,
            isClearEnabled: !name.isEmpty || selectedCharacterIndex != nil,
            onSelectCharacter: { selectedCharacterIndex = $0 },
            onClear: { name = ""; selectedCharacterIndex = nil },
            onSave: {},
            onBack: showsBack ? {} : nil
        )
    }
}
