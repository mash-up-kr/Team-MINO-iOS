import SwiftUI
import DesignSystem

// MARK: - 캐릭터 스와치

/// 캐릭터 선택 12색. 순서는 피그마 4열×3행 그리드(좌→우, 상→하)와 동일하다.
///
/// 캐릭터 아트 대신 색으로만 구분하므로 12개가 서로 겹치면 안 된다.
/// Accent/Foreground(11종)로 채우고 모자란 하나만 Background 계열에서 가져온다.
/// 피그마 캐릭터는 토큰이 아니라 이미지라 대응되는 변수가 없다 — 색상은 계열 근사다.
/// 아트가 준비되면 `.color` 를 `.image` 로 바꿔 끼운다.
private let characterSwatches: [MHSelectionGridItem] = [
    .color(fill: .mhAccentForegroundRed, border: .mhLineNormalAlternative),         // 0: 빨강
    .color(fill: .mhAccentForegroundOrange, border: .mhLineNormalAlternative),      // 1: 노랑주황
    .color(fill: .mhAccentForegroundRedOrange, border: .mhLineNormalAlternative),   // 2: 주황
    .color(fill: .mhAccentForegroundGreen, border: .mhLineNormalAlternative),       // 3: 민트 그린
    .color(fill: .mhAccentForegroundViolet, border: .mhLineNormalAlternative),      // 4: 라벤더
    .color(fill: .mhAccentForegroundLime, border: .mhLineNormalAlternative),        // 5: 그린
    .color(fill: .mhAccentForegroundCyan, border: .mhLineNormalAlternative),        // 6: 하늘색
    .color(fill: .mhAccentForegroundPink, border: .mhLineNormalAlternative),        // 7: 핑크
    .color(fill: .mhAccentForegroundBlue, border: .mhLineNormalAlternative),        // 8: 블루
    .color(fill: .mhAccentBackgroundRedOrange, border: .mhLineNormalAlternative),   // 9: 베이지 — Foreground 에 대응색이 없어 옅은 계열로
    .color(fill: .mhAccentForegroundLightBlue, border: .mhLineNormalAlternative),   // 10: 터콰이즈
    .color(fill: .mhAccentForegroundPurple, border: .mhLineNormalAlternative),      // 11: 퍼플
]

// [Convention] .claude/docs/mvi-coordinator-di.md — Store·Coordinator 를 모르는 순수 마크업.
// Figma `001-1. 프로필 설정` (node 1645:18880 저장 활성 / 1645:18927 비활성) — 두 상태를 값(`isSaveEnabled`)으로만 그린다.
/// 프로필 설정 화면의 마크업. 이름 입력 + 캐릭터(색상) 선택 + 저장/지우기 액션으로 구성된다.
///
/// 캐릭터 아트는 아직 없어 색으로만 구분한다(실제 캐릭터 이미지는 추후 교체 예정 — 기획 확정 사항).
struct ProfileSetupContent: View {
    /// 이름/닉네임 입력값. 입력 필드는 SUITE 대신 시스템 폰트를 쓴다(`MHTextField` 내부 규칙, DesignSystem README 참조).
    @Binding var name: String
    /// 선택된 캐릭터 인덱스(0~11). `nil` 이면 아직 아무 캐릭터도 고르지 않은 상태.
    let selectedCharacterIndex: Int?
    /// 저장 가능 여부. 이름 유효성 등 판단은 다음 PR 의 Store 몫 — 여기서는 받은 값으로만 활성/비활성을 그린다.
    let isSaveEnabled: Bool
    /// 지우기 가능 여부. 저장과 조건이 달라 따로 받는다.
    let isClearEnabled: Bool
    let onSelectCharacter: (Int) -> Void
    let onClear: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MHTopNavigation(title: "프로필 설정")
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
    }

    // MARK: - 큰 미리보기 원 (120x120, border 5 Line/Normal/Alternative)

    private var previewAvatar: some View {
        ZStack {
            Circle().fill(Color.mhLineNormalAlternative)
            Circle().fill(previewColor).padding(5)
        }
        .frame(width: 120, height: 120)
        .accessibilityIdentifier("ProfileSetup.previewAvatar")
    }

    // 선택 전엔 캐릭터 색이 없어 중립 배경으로 둔다(Figma 는 두 상태 모두 선택된 예시만 보여줘 무선택 색은 실측 불가 — 판단 근거).
    private var previewColor: Color {
        guard let selectedCharacterIndex, characterSwatches.indices.contains(selectedCharacterIndex),
              case .color(let fill, _) = characterSwatches[selectedCharacterIndex] else {
            return .mhBackgroundNormalAlternative
        }
        return fill
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

#Preview("저장 활성") {
    ProfileSetupContentPreviewWrapper(name: "민호", selectedCharacterIndex: 5, isSaveEnabled: true)
}

#Preview("저장 비활성") {
    ProfileSetupContentPreviewWrapper(name: "", selectedCharacterIndex: nil, isSaveEnabled: false)
}

// 저장은 막히고 지우기는 열리는 구간(이름 1글자) — 두 버튼이 갈리는 유일한 상태다.
#Preview("저장만 비활성") {
    ProfileSetupContentPreviewWrapper(name: "민", selectedCharacterIndex: nil, isSaveEnabled: false)
}

// #Preview 클로저는 @State 를 직접 못 가져 바인딩용 래퍼로 감싼다.
private struct ProfileSetupContentPreviewWrapper: View {
    @State var name: String
    @State var selectedCharacterIndex: Int?
    let isSaveEnabled: Bool

    var body: some View {
        ProfileSetupContent(
            name: $name,
            selectedCharacterIndex: selectedCharacterIndex,
            isSaveEnabled: isSaveEnabled,
            isClearEnabled: !name.isEmpty,
            onSelectCharacter: { selectedCharacterIndex = $0 },
            onClear: { name = "" },
            onSave: {}
        )
    }
}
