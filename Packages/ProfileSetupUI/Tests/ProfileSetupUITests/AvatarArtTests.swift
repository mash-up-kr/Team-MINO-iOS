import DesignSystem
import Domain
import Testing
@testable import ProfileSetupUI

/// 프리셋 번호 → 얼굴 매핑을 고정한다. 어긋나면 같은 사람이 화면마다 다른 얼굴로 뜨는데,
/// 그 어긋남은 화면을 봐야만 드러난다.
struct AvatarArtTests {
    @Test("프리셋 번호는 1부터 — 1번이 그리드 첫 캐릭터다")
    func firstIDIsFirstCharacter() {
        #expect(AvatarArt.character(for: 1) == MHCharacter.allCases[0])
        #expect(AvatarArt.character(for: 12) == MHCharacter.allCases[11])
    }

    @Test("팔레트를 벗어난 번호는 되감아 쓴다 — 빈 얼굴을 띄우지 않는다")
    func outOfRangeIDWraps() {
        #expect(AvatarArt.character(for: 13) == AvatarArt.character(for: 1))
        #expect(AvatarArt.character(for: 0) == AvatarArt.character(for: 12))
    }

    @Test("번호 → 얼굴은 AvatarPalette 표와 같다 — 프로필 설정 화면과 다른 얼굴이 되지 않는다")
    func matchesPalette() {
        for id in 1...AvatarPalette.entries.count {
            #expect(AvatarArt.character(for: id) == AvatarPalette.character(at: id - 1))
        }
    }

    @Test("한 줄에 늘어놓는 얼굴은 displayLimit 개까지")
    func imagesAreCapped() {
        let ids = Array(1...(AvatarArt.displayLimit + 3))
        #expect(AvatarArt.images(for: ids).count == AvatarArt.displayLimit)
    }

    @Test("저장자가 없으면 배열이 비어 아바타 자리 자체가 사라진다")
    func absentProfileYieldsNoAvatar() {
        let absent = AvatarArt.images(for: MemberProfile?.none)
        let present = AvatarArt.images(for: MemberProfile(id: MemberID("u"), nickname: "나", avatarID: 2))
        #expect(absent.isEmpty)
        #expect(present.count == 1)
    }
}
