/// 튜토리얼이 넘겨 보여주는 예시 한 장. Figma `000-1 튜토리얼_step 1` ~ `000-5 튜토리얼_step 5`.
struct TutorialStep: Equatable, Identifiable {
    /// 화면의 번호 뱃지에 그대로 쓰는 1-based 순번.
    let id: Int
    let title: String
    let illustration: Illustration

    enum Illustration: Equatable {
        /// `Illustration.xcassets` 의 이미지 이름.
        case asset(String)
        /// 아직 시안이 나오지 않은 자리. Figma 도 회색 카드에 설명 문구만 얹어 두었다.
        case placeholder(String)
    }
}

extension TutorialStep {
    // 개행은 시안이 끊어 둔 그대로다 — 폭에 맡기면 끊기는 지점이 달라진다.
    static let all: [TutorialStep] = [
        TutorialStep(
            id: 1,
            title: "인스타그램 공유 버튼\n찾아서 눌러주기",
            illustration: .asset("tutorialStep1")
        ),
        TutorialStep(
            id: 2,
            title: "공유 대상 버튼\n찾아서 눌러주기",
            illustration: .asset("tutorialStep2")
        ),
        TutorialStep(
            id: 3,
            title: "앱 목록을 쓸어넘겨\n더보기 버튼 눌러주기",
            illustration: .asset("tutorialStep3")
        ),
        TutorialStep(
            id: 4,
            title: "앱 목록을 쓸어내려\n꾹 앱 눌러주기",
            illustration: .asset("tutorialStep4")
        ),
        TutorialStep(
            id: 5,
            title: "꾹에 공유하기만 하면\n지도에 추가 완료",
            // TODO: 시안이 나오면 .asset("tutorialStep5") 로 바꾼다(Figma node 3798:167145 가 아직 플레이스홀더).
            illustration: .placeholder("꾹 앱 지도화면에\n핀마커가 표시되어있는 장면")
        )
    ]
}
