import DesignSystem
import Domain
import Testing
@testable import ProfileSetupUI

/// 인덱스 ↔ 색 ↔ 캐릭터를 잇는 표가 어긋나면 **저장된 프로필이 다른 캐릭터를 가리킨다.**
/// 그 어긋남은 화면을 봐야만 드러나므로 여기서 고정한다.
struct AvatarPaletteTests {
    // 서버 스펙의 enum 을 그대로 옮긴 값이다. 하나라도 어긋나면 400 이다.
    @Test("서버 전송 문자열(rawValue)을 고정한다")
    func rawValuesMatchServerContract() {
        #expect(Set(AvatarColor.allCases.map(\.rawValue)) == [
            "red", "red_orange", "orange", "green", "purple", "lime",
            "cyan", "pink", "blue", "brown", "light_blue", "violet", "gray",
        ])
    }

    // gray 는 "안 고름" 을 표현하는 값이라 그리드에 칸이 없다 — 방 색(RoomColor.gray)과 같은 자리다.
    @Test("gray 는 그리드에 칸이 없다")
    func grayHasNoGridSlot() {
        #expect(AvatarPalette.index(of: .gray) == nil)
        #expect(!AvatarPalette.entries.map(\.color).contains(.gray))
    }

    @Test("캐릭터 12종과 gray 를 뺀 색 12종이 하나씩 짝지어진다")
    func entriesArePairedOneToOne() {
        #expect(AvatarPalette.entries.count == 12)
        #expect(Set(AvatarPalette.entries.map(\.character)).count == 12)
        #expect(Set(AvatarPalette.entries.map(\.color)) == Set(AvatarColor.allCases).subtracting([.gray]))
    }

    // 그리드 순서가 곧 저장되는 색이다. 재정렬하면 기존 프로필이 다른 캐릭터가 된다.
    @Test("선언 순서가 Figma 그리드 순서(좌→우, 상→하)와 같다")
    func orderMatchesFigmaGrid() {
        #expect(AvatarPalette.entries.map(\.character) == MHCharacter.allCases)
    }

    @Test("색 ↔ 인덱스가 왕복한다")
    func colorAndIndexRoundTrip() {
        for (index, entry) in AvatarPalette.entries.enumerated() {
            #expect(AvatarPalette.color(at: index) == entry.color)
            #expect(AvatarPalette.index(of: entry.color) == index)
        }
    }

    // 서버 팔레트가 우리보다 앞서 나가거나 배선이 어긋나도 화면이 빈 자리를 그리면 안 된다.
    @Test("범위 밖 인덱스는 첫 캐릭터로 떨어진다")
    func outOfRangeFallsBackToFirst() {
        #expect(AvatarPalette.color(at: -1) == .red)
        #expect(AvatarPalette.color(at: 99) == .red)
        #expect(AvatarPalette.character(at: 99) == .character01)
    }

    // MARK: - 홈 마스코트

    @Test("색 12종이 마스코트 12종과 하나씩 짝지어진다 — 기본(plain)은 색이 아니다")
    func mascotsArePairedOneToOne() {
        let mascots = Set(AvatarPalette.entries.map(\.mascot))
        #expect(mascots.count == 12)
        #expect(!mascots.contains(.plain))
        #expect(mascots.union([.plain]) == Set(MHHomeMascot.allCases))
    }

    @Test("색으로 고른 마스코트는 그리드 표와 같다")
    func mascotMatchesTable() {
        for entry in AvatarPalette.entries {
            #expect(AvatarPalette.homeMascot(of: entry.color) == entry.mascot)
        }
    }

    // 얼굴(character)과 달리 마스코트는 시안이 "안 고름" 그림을 따로 준다.
    @Test("아바타 색이 없거나 gray 면 소품 없는 기본 마스코트다")
    func absentColorFallsBackToPlain() {
        #expect(AvatarPalette.homeMascot(of: nil) == .plain)
        #expect(AvatarPalette.homeMascot(of: .gray) == .plain)
        // 이전 세대 아트(MHCharacter)에는 "안 고름" 그림이 없어 1번으로 떨어진다.
        #expect(AvatarPalette.character(of: nil) == .character01)
        #expect(AvatarPalette.character(of: .gray) == .character01)
    }

    // MARK: - 아바타 프로필 아트
    //
    // 아바타 슬롯과 프로필 선택 그리드가 함께 쓰는 새 아트(`character/Avatar Profile`)다.

    @Test("12색이 서로 다른 아바타 프로필로 짝지어진다 — 기본(plain)은 색이 아니다")
    func profilesAreDistinct() {
        let profiles = Set(AvatarPalette.entries.map(\.profile))
        #expect(profiles.count == AvatarPalette.entries.count)
        // 13종 중 `plain` 만 그리드 밖에 남는다 — "아직 안 고름" 자리.
        #expect(profiles.union([.plain]) == Set(MHAvatarProfile.allCases))
    }

    @Test("색으로 고른 아바타 프로필은 그리드 표와 같다")
    func profileMatchesTable() {
        for entry in AvatarPalette.entries {
            #expect(AvatarPalette.profile(of: entry.color) == entry.profile)
        }
    }

    // 그리드는 색이 아니라 자리(인덱스)로 고른다 — 색 경로와 별개로 고정한다.
    @Test("그리드 자리마다 정해진 아바타 프로필이 나온다")
    func profileMatchesTableByIndex() {
        for (index, entry) in AvatarPalette.entries.enumerated() {
            #expect(AvatarPalette.profile(at: index) == entry.profile)
        }
        #expect(AvatarPalette.profiles == AvatarPalette.entries.map(\.profile))
    }

    // 마스코트와 같은 근거 — 시안(010-1)이 무선택 자리에 "안 고름" 그림을 따로 준다.
    // 남의 계정을 빨간 캐릭터로 그리면 그 사람이 빨강을 고른 것처럼 보인다.
    @Test("무선택·gray·범위 밖은 소품 없는 검은 프로필이다")
    func absentSelectionFallsBackToPlainProfile() {
        #expect(AvatarPalette.profile(of: nil) == .plain)
        #expect(AvatarPalette.profile(of: .gray) == .plain)
        #expect(AvatarPalette.profile(at: nil) == .plain)
        #expect(AvatarPalette.profile(at: -1) == .plain)
        #expect(AvatarPalette.profile(at: 99) == .plain)
    }

    @Test("한 줄에 늘어놓는 얼굴은 displayLimit 개까지")
    func imagesAreCapped() {
        let colors: [AvatarColor?] = Array(repeating: .red, count: AvatarPalette.displayLimit + 3)
        #expect(AvatarPalette.images(of: colors).count == AvatarPalette.displayLimit)
    }
}
