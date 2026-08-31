import DesignSystem
import Domain
import SwiftUI

/// 인덱스 ↔ 도메인 색 ↔ 캐릭터 그림 ↔ 홈 마스코트를 잇는 **단일 이음매**.
///
/// 네 어휘가 각자 다른 이유로 존재한다 — 화면은 그리드 자리(인덱스)로 고르고, 서버는 색 이름만
/// 알며(`avatar.color`), 프로필 그림은 `MHCharacter`, 홈 우상단 마스코트는 `MHHomeMascot` 다.
/// 넷을 잇는 표를 여기 한 곳에만 두어 어긋난 매핑이 여러 곳에 생기지 않게 한다.
/// (`RoomColorPalette` 와 같은 역할)
///
/// > ⚠️ **순서가 곧 계약이다.** 선언 순서가 Figma 그리드(좌→우, 상→하)이자 저장되는 색이므로,
/// > 재정렬하면 이미 저장된 프로필이 다른 캐릭터를 가리킨다. 색은 캐릭터 아트의 대표색을
/// > Atomic 팔레트와 대조해 정했다(`character07`·`character12` 는 팔레트 색과 정확히 일치).
public enum AvatarPalette {
    /// 그리드 한 자리가 잇는 네 어휘.
    ///
    /// 아바타·마스코트는 Figma 가 **색 이름으로** 배리언트를 나눠 둔 별개 아트라
    /// (`character/Avatar Profile`·`character/Home_Avatar`), 캐릭터 그림에서 유도하지 않고
    /// 색에 직접 붙인다.
    ///
    /// > `character` 는 **이전 세대 아트**다. 프로필 설정 화면만 새 `avatar` 로 옮겼고,
    /// > 댓글·아바타 그룹 등 나머지 자리는 아직 `character` 를 그린다.
    struct Entry {
        let character: MHCharacter
        let avatar: MHAvatarProfile
        let color: AvatarColor
        let mascot: MHHomeMascot
    }

    /// 그리드 순서대로의 표.
    static let entries: [Entry] = [
        Entry(character: .character01, avatar: .red, color: .red, mascot: .red),
        Entry(character: .character02, avatar: .redOrange, color: .redOrange, mascot: .redOrange),
        Entry(character: .character03, avatar: .orange, color: .orange, mascot: .orange),
        Entry(character: .character04, avatar: .green, color: .green, mascot: .green),
        Entry(character: .character05, avatar: .purple, color: .purple, mascot: .purple),
        Entry(character: .character06, avatar: .lime, color: .lime, mascot: .lime),
        Entry(character: .character07, avatar: .cyan, color: .cyan, mascot: .cyan),
        Entry(character: .character08, avatar: .pink, color: .pink, mascot: .pink),
        Entry(character: .character09, avatar: .blue, color: .blue, mascot: .blue),
        Entry(character: .character10, avatar: .brown, color: .brown, mascot: .brown),
        Entry(character: .character11, avatar: .lightBlue, color: .lightBlue, mascot: .lightBlue),
        Entry(character: .character12, avatar: .violet, color: .violet, mascot: .violet)
    ]

    /// 범위 밖 인덱스가 떨어지는 자리. **무선택의 값이 아니다** — 무선택은 `AvatarColor.gray` 이고
    /// 그림은 소품 없는 기본 아바타다(``avatar(at:)``).
    static let `default` = entries[0]

    static var avatars: [MHAvatarProfile] { entries.map(\.avatar) }

    static func color(at index: Int) -> AvatarColor {
        entries.indices.contains(index) ? entries[index].color : `default`.color
    }

    static func character(at index: Int) -> MHCharacter {
        entries.indices.contains(index) ? entries[index].character : `default`.character
    }

    /// 그리드 자리 → 아바타 그림. 아직 안 골랐거나(`nil`) 범위 밖이면 소품 없는 기본 아바타다 —
    /// 시안 `010-1`(2314:95662)이 무선택 미리보기에 `black` 배리언트를 그린다.
    /// (``homeMascot(of:)`` 가 색을 모를 때 `.plain` 으로 떨어지는 것과 같은 근거)
    static func avatar(at index: Int?) -> MHAvatarProfile {
        index.flatMap { entries.indices.contains($0) ? entries[$0].avatar : nil } ?? .plain
    }

    /// 서버가 준 색이 그리드 몇 번째인가. 그리드에 칸이 없는 색(`gray`)이거나 모르는 색이면
    /// `nil` — 화면은 무선택으로 그린다.
    static func index(of color: AvatarColor) -> Int? {
        entries.firstIndex { $0.color == color }
    }

    /// 도메인 색으로 캐릭터 그림을 얻는다 — **프로필을 그리기만 하는 화면**(마이페이지 요약)이 쓴다.
    ///
    /// 색을 모르거나(서버 팔레트가 우리보다 앞서 나간 경우) 아직 아바타가 없는 계정, `gray` 면
    /// 1번으로 떨어진다. ``MHCharacter`` 는 **이전 세대 아트**라 "안 고름" 그림이 없어서다 —
    /// 새 아트(``avatar(at:)``)로 옮긴 화면은 그 자리에 `plain` 을 그린다.
    public static func character(of color: AvatarColor?) -> MHCharacter {
        color.flatMap(index(of:)).map(character(at:)) ?? `default`.character
    }

    /// 도메인 색으로 얼굴 그림을 얻는다 — 아바타 그룹·스택처럼 `Image` 를 바로 받는 자리가 쓴다.
    public static func image(of color: AvatarColor?) -> Image {
        Image(character(of: color))
    }

    /// 한 줄에 얼굴을 몇 개까지 늘어놓는가. 넘치는 인원은 그리지 않는다(시안에 "+N" 배지가 없다).
    public static let displayLimit = 5

    /// 아바타 그룹·스택에 넘길 이미지 배열. ``displayLimit`` 까지만 자른다.
    public static func images(of colors: [AvatarColor?]) -> [Image?] {
        colors.prefix(displayLimit).map(image(of:))
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
