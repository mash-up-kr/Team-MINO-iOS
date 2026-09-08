import DesignSystem
import Domain
import SwiftUI

/// 인덱스 ↔ 도메인 색 ↔ 그림 세 종류를 잇는 **단일 이음매**.
///
/// 어휘가 각자 다른 이유로 존재한다 — 화면은 그리드 자리(인덱스)로 고르고, 서버는 색 이름만
/// 알며(`avatar.color`), 그림은 자리마다 다르다: 프로필·아바타 슬롯은 `MHAvatarProfile`,
/// 홈 우상단 마스코트는 `MHHomeMascot` 이다.
/// 이들을 잇는 표를 여기 한 곳에만 두어 어긋난 매핑이 여러 곳에 생기지 않게 한다.
/// (`RoomColorPalette` 와 같은 역할)
///
/// > ⚠️ **순서가 곧 계약이다.** 선언 순서가 Figma 그리드(좌→우, 상→하)이자 저장되는 색이므로,
/// > 재정렬하면 이미 저장된 프로필이 다른 캐릭터를 가리킨다. 색은 캐릭터 아트의 대표색을
/// > Atomic 팔레트와 대조해 정했다(`character07`·`character12` 는 팔레트 색과 정확히 일치).
public enum AvatarPalette {
    /// 그리드 한 자리가 잇는 네 어휘.
    ///
    /// 마스코트·아바타 프로필은 Figma 가 **색 이름으로** 배리언트를 나눠 둔 별개 아트라
    /// (`character/Home_Avatar`·`character/Avatar Profile`), 캐릭터 그림에서 유도하지 않고
    /// 색에 직접 붙인다. 이름이 같아도 `rawValue` 로 잇지 않고 여기서 명시적으로 짝짓는다 —
    /// 이름으로 이으면 한쪽 enum 이 바뀌어도 컴파일이 통과하고 런타임에 그림만 조용히 사라진다.
    ///
    /// 튜플이 아니라 구조체인 이유는 열이 넷이라서다 — 3-멤버부터 SwiftLint `large_tuple` 이
    /// 경고하고 4-멤버는 에러다.
    struct Entry {
        /// 이전 세대 아트. 지금 그리는 화면은 없고 **그리드 순서 계약의 기준**으로만 남는다
        /// (선언 순서 = 저장되는 색 — `AvatarPaletteTests.orderMatchesFigmaGrid`).
        let character: MHCharacter
        let color: AvatarColor
        let mascot: MHHomeMascot
        let profile: MHAvatarProfile
    }

    /// 그리드 순서대로의 표.
    static let entries: [Entry] = [
        Entry(character: .character01, color: .red, mascot: .red, profile: .red),
        Entry(character: .character02, color: .redOrange, mascot: .redOrange, profile: .redOrange),
        Entry(character: .character03, color: .orange, mascot: .orange, profile: .orange),
        Entry(character: .character04, color: .green, mascot: .green, profile: .green),
        Entry(character: .character05, color: .purple, mascot: .purple, profile: .purple),
        Entry(character: .character06, color: .lime, mascot: .lime, profile: .lime),
        Entry(character: .character07, color: .cyan, mascot: .cyan, profile: .cyan),
        Entry(character: .character08, color: .pink, mascot: .pink, profile: .pink),
        Entry(character: .character09, color: .blue, mascot: .blue, profile: .blue),
        Entry(character: .character10, color: .brown, mascot: .brown, profile: .brown),
        Entry(character: .character11, color: .lightBlue, mascot: .lightBlue, profile: .lightBlue),
        Entry(character: .character12, color: .violet, mascot: .violet, profile: .violet)
    ]

    /// 범위 밖 인덱스가 떨어지는 자리. **무선택의 값이 아니다** — 무선택은 `AvatarColor.gray` 이고
    /// 그림은 소품 없는 기본 아바타다(``profile(at:)``).
    static let `default` = entries[0]

    /// 선택 그리드에 늘어놓을 그림.
    static var profiles: [MHAvatarProfile] { entries.map(\.profile) }

    static func color(at index: Int) -> AvatarColor {
        entries.indices.contains(index) ? entries[index].color : `default`.color
    }

    /// 그리드 자리 → 아바타 그림. 아직 안 골랐거나(`nil`) 범위 밖이면 소품 없는 기본 아바타다 —
    /// 시안 `010-1`(2314:95662)이 무선택 미리보기에 `black` 배리언트를 그린다.
    /// (``homeMascot(of:)``·``profile(of:)`` 가 색을 모를 때 `.plain` 으로 떨어지는 것과 같은 근거)
    static func profile(at index: Int?) -> MHAvatarProfile {
        index.flatMap { entries.indices.contains($0) ? entries[$0].profile : nil } ?? .plain
    }

    /// 서버가 준 색이 그리드 몇 번째인가. 그리드에 칸이 없는 색(`gray`)이거나 모르는 색이면
    /// `nil` — 화면은 무선택으로 그린다.
    static func index(of color: AvatarColor) -> Int? {
        entries.firstIndex { $0.color == color }
    }

    /// 도메인 색으로 **아바타 프로필 아트**(`character/Avatar Profile`)를 얻는다.
    ///
    /// 색을 아직 고르지 않았거나 우리가 모르는 색이면 ``MHAvatarProfile/plain`` — 소품 없는 검은
    /// 얼굴로, 시안이 "아바타 색을 아직 고르지 않은 계정 자리" 로 마련해 둔 배리언트다.
    /// (1번 캐릭터로 떨어뜨리면 안 된다 — 남의 계정을 빨간 캐릭터로 그리면 그 사람이 빨강을
    /// 고른 것처럼 보인다.)
    static func profile(of color: AvatarColor?) -> MHAvatarProfile {
        color.flatMap(index(of:)).map { entries[$0].profile } ?? .plain
    }

    /// 도메인 색으로 얼굴 그림을 얻는다 — 아바타 그룹·스택처럼 `Image` 를 바로 받는 자리가 쓴다.
    ///
    /// 아바타 슬롯(``MHAvatar``·``MHAvatarGroup``·``MHAvatarStack``·``MHComment``)·프로필 선택
    /// 그리드·마이페이지 큰 프로필이 모두 이 아트를 쓴다.
    public static func image(of color: AvatarColor?) -> Image {
        Image(profile(of: color))
    }

    /// 카운터 없이 전부 겹쳐 그리는 인원의 상한.
    /// PRD 「방 멤버 아바타」 — "**4명 이하**: 멤버 아바타를 있는 대로 모두 겹쳐 표시하고,
    /// 카운터는 붙이지 않는다."
    public static let maxOverlapped = 4

    /// 5명 이상일 때 그리는 얼굴 수 — 나머지는 카운터 칩이 맡는다.
    /// PRD — "**5명 이상**: **아바타 3개 + 카운터 칩**으로 표시한다."
    public static let overlappedWhenCounting = 3

    /// 멤버 아바타 줄에 그릴 얼굴과 카운터에 남길 인원.
    ///
    /// PRD 「방 멤버 아바타」의 두 갈래(4명 이하 / 5명 이상)와 정렬 규칙을 **한자리에서** 정한다 —
    /// 방 카드와 방 상세 헤더가 같은 규칙을 봐야 해서다(그 정의도 "방 카드·방 상세 헤더에 겹쳐
    /// 노출되는 멤버 프로필" 로 두 화면을 함께 묶는다).
    ///
    /// - Parameter colors: **서버 순서**(최근에 장소를 저장한 멤버가 먼저)의 아바타 색.
    ///   `GET /rooms/{roomId}/members` 와 방 목록 `?showUsers=true` 가 둘 다 이 순서로 준다.
    /// - Returns: 그릴 이미지와 카운터 값(4명 이하면 `nil`).
    ///   이미지는 **왼→오 순서**로, 오른쪽 끝이 최근 저장자다 — PRD "가장 최근에 장소를 저장한
    ///   사람이 아바타 중 가장 오른쪽에 오도록 우→좌로 정렬한다".
    public static func overlapped(_ colors: [AvatarColor?]) -> (images: [Image?], overflow: Int?) {
        let picked = overlappedColors(colors)
        return (picked.colors.map(image(of:)), picked.overflow)
    }

    /// ``overlapped(_:)`` 의 색 단계. 규칙을 **테스트로 고정할 수 있게** 갈라 뒀다 —
    /// `Image` 는 값 비교를 지원하지 않아 이미지 배열로는 순서를 단언할 수 없다.
    ///
    /// - Returns: 화면 순서(왼→오)의 색과, 접혀서 카운터로 넘어간 인원(4명 이하면 `nil`).
    ///   접히는 것은 **가장 오래된 쪽**이다 — 최근 저장자 3명이 남는다.
    public static func overlappedColors(
        _ colors: [AvatarColor?]
    ) -> (colors: [AvatarColor?], overflow: Int?) {
        guard colors.count > maxOverlapped else {
            return (colors.reversed(), nil)
        }
        return (
            colors.prefix(overlappedWhenCounting).reversed(),
            colors.count - overlappedWhenCounting
        )
    }

    /// 프로필 하나를 그룹 API(`[Image?]`)에 실을 때. 없으면 빈 배열이라 자리 자체가 사라진다 —
    /// 익명 회색 원을 대신 띄우면 "이름 모를 누군가"로 읽혀 없는 정보를 있는 것처럼 보이게 한다.
    public static func images(of profile: MemberProfile?) -> [Image?] {
        profile.map { [image(of: $0.avatarColor)] } ?? []
    }

    /// 도메인 색으로 홈 우상단 마스코트를 얻는다 (Figma `character/Home_Avatar`).
    ///
    /// ``character(of:)`` 와 달리 `gray`(안 고름)·모르는 색이면 **1번이 아니라 소품 없는 기본
    /// 마스코트**로 떨어진다 — 시안이 그 자리에 `black` 배리언트를 따로 두고 있어서다. 색을 고른
    /// 적 없는 계정에 남의 셰프 모자를 씌우는 것보다, 시안이 정해 둔 그림을 그대로 쓰는 편이 맞다.
    public static func homeMascot(of color: AvatarColor?) -> MHHomeMascot {
        color.flatMap(index(of:)).map { entries[$0].mascot } ?? .plain
    }
}
