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
    /// 그리드 순서대로의 (캐릭터, 색, 홈 마스코트, 아바타 프로필) 쌍.
    ///
    /// 마스코트·아바타 프로필은 Figma 가 **색 이름으로** 배리언트를 나눠 둔 별개 아트라
    /// (`character/Home_Avatar`·`character/Avatar Profile`), 캐릭터 그림에서 유도하지 않고 색에 직접 붙인다.
    ///
    /// 이름이 같아도 `rawValue` 로 잇지 않고 여기서 명시적으로 짝짓는다 — 이름으로 이으면 한쪽 enum 이
    /// 바뀌어도 컴파일이 통과하고 런타임에 그림만 조용히 사라진다(`ArchiveMap.tint` 와 같은 판단).
    static let entries: [(
        character: MHCharacter, color: AvatarColor, mascot: MHHomeMascot, profile: MHAvatarProfile
    )] = [
        (.character01, .red, .red, .red),
        (.character02, .redOrange, .redOrange, .redOrange),
        (.character03, .orange, .orange, .orange),
        (.character04, .green, .green, .green),
        (.character05, .purple, .purple, .purple),
        (.character06, .lime, .lime, .lime),
        (.character07, .cyan, .cyan, .cyan),
        (.character08, .pink, .pink, .pink),
        (.character09, .blue, .blue, .blue),
        (.character10, .brown, .brown, .brown),
        (.character11, .lightBlue, .lightBlue, .lightBlue),
        (.character12, .violet, .violet, .violet),
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

    /// 도메인 색으로 캐릭터 그림을 얻는다 — **프로필을 그리기만 하는 화면**(마이페이지 요약)이 쓴다.
    ///
    /// 색을 모르거나(서버 팔레트가 우리보다 앞서 나간 경우) 아직 아바타가 없는 계정이면 1번으로
    /// 떨어진다. 설정 화면의 무선택 미리보기와 같은 폴백이라(`ProfileSetupContent.previewCharacter`)
    /// 두 화면이 같은 계정을 다르게 그리지 않는다.
    public static func character(of color: AvatarColor?) -> MHCharacter {
        color.flatMap(index(of:)).map(character(at:)) ?? `default`.character
    }

    /// 도메인 색으로 **아바타 프로필 아트**(`character/Avatar Profile`)를 얻는다.
    ///
    /// 색을 아직 고르지 않았거나 우리가 모르는 색이면 ``MHAvatarProfile/plain`` — 소품 없는 검은
    /// 얼굴로, 시안이 "아바타 색을 아직 고르지 않은 계정 자리" 로 마련해 둔 배리언트다.
    /// (얼굴 쪽 `character(of:)` 는 1번으로 떨어지지만, 그건 **내가 고르는** 그리드의 폴백이라 다르다 —
    /// 남의 계정을 빨간 캐릭터로 그리면 그 사람이 빨강을 고른 것처럼 보인다.)
    static func profile(of color: AvatarColor?) -> MHAvatarProfile {
        color.flatMap(index(of:)).map { entries[$0].profile } ?? .plain
    }

    /// 도메인 색으로 얼굴 그림을 얻는다 — 아바타 그룹·스택처럼 `Image` 를 바로 받는 자리가 쓴다.
    ///
    /// 아바타 슬롯(``MHAvatar``·``MHAvatarGroup``·``MHAvatarStack``·``MHComment``)은 모두 새 아트를 쓴다.
    /// 프로필 **선택** 그리드(`characters`)와 마이페이지 큰 프로필은 아직 이전 세대 아트(``MHCharacter``)다 —
    /// 그리드는 "선언 순서 = 저장되는 색" 이라는 계약이 걸려 있어 별도 작업으로 둔다.
    public static func image(of color: AvatarColor?) -> Image {
        Image(profile(of: color))
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
    /// ``character(of:)`` 와 달리 색을 모르면 **1번이 아니라 소품 없는 기본 마스코트**로 떨어진다 —
    /// 시안이 그 자리에 `black` 배리언트를 따로 두고 있어서다. 색을 고른 적 없는 계정에 남의
    /// 셰프 모자를 씌우는 것보다, 시안이 정해 둔 "아직 안 고름" 그림을 그대로 쓰는 편이 맞다.
    public static func homeMascot(of color: AvatarColor?) -> MHHomeMascot {
        color.flatMap(index(of:)).map { entries[$0].mascot } ?? .plain
    }
}
