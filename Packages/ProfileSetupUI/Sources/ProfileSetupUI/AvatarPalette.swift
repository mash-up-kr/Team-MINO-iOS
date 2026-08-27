import DesignSystem
import Domain

/// 인덱스 ↔ 도메인 색 ↔ 캐릭터 그림을 잇는 **단일 이음매**.
///
/// 세 어휘가 각자 다른 이유로 존재한다 — 화면은 그리드 자리(인덱스)로 고르고, 서버는 색 이름만
/// 알며(`avatar.color`), 그림은 `MHCharacter` 다. 셋을 잇는 표를 여기 한 곳에만 두어
/// 어긋난 매핑이 여러 곳에 생기지 않게 한다. (`RoomColorPalette` 와 같은 역할)
///
/// > ⚠️ **순서가 곧 계약이다.** 선언 순서가 Figma 그리드(좌→우, 상→하)이자 저장되는 색이므로,
/// > 재정렬하면 이미 저장된 프로필이 다른 캐릭터를 가리킨다. 색은 캐릭터 아트의 대표색을
/// > Atomic 팔레트와 대조해 정했다(`character07`·`character12` 는 팔레트 색과 정확히 일치).
enum AvatarPalette {
    /// 그리드 순서대로의 (캐릭터, 색) 쌍.
    static let entries: [(character: MHCharacter, color: AvatarColor)] = [
        (.character01, .red),
        (.character02, .redOrange),
        (.character03, .orange),
        (.character04, .green),
        (.character05, .purple),
        (.character06, .lime),
        (.character07, .cyan),
        (.character08, .pink),
        (.character09, .blue),
        (.character10, .brown),
        (.character11, .lightBlue),
        (.character12, .violet),
    ]

    /// 아무것도 안 고른 상태에서 보여주고 저장하는 값 — 시안 010-1 이 미리보기에 1번을 띄운다.
    static let `default` = entries[0]

    static var characters: [MHCharacter] { entries.map(\.character) }

    static func color(at index: Int) -> AvatarColor {
        entries.indices.contains(index) ? entries[index].color : `default`.color
    }

    static func character(at index: Int) -> MHCharacter {
        entries.indices.contains(index) ? entries[index].character : `default`.character
    }

    /// 서버가 준 색이 그리드 몇 번째인가. 모르는 색이면 `nil` — 화면은 무선택으로 그린다.
    static func index(of color: AvatarColor) -> Int? {
        entries.firstIndex { $0.color == color }
    }
}
