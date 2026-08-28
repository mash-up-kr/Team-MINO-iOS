import DesignSystem
import Domain
import Testing

@testable import FeatureArchive

struct ArchiveAvatarArtTests {
    @Test("프리셋 번호는 1부터 — 1번이 그리드 첫 캐릭터다")
    func firstIDIsFirstCharacter() {
        #expect(ArchiveAvatarArt.character(for: 1) == MHCharacter.allCases[0])
        #expect(ArchiveAvatarArt.character(for: 12) == MHCharacter.allCases[11])
    }

    @Test("팔레트를 벗어난 번호는 되감아 쓴다 — 빈 얼굴을 띄우지 않는다")
    func outOfRangeIDWraps() {
        #expect(ArchiveAvatarArt.character(for: 13) == ArchiveAvatarArt.character(for: 1))
        #expect(ArchiveAvatarArt.character(for: 0) == ArchiveAvatarArt.character(for: 12))
    }

    @Test("한 줄에 늘어놓는 얼굴은 displayLimit 개까지")
    func imagesAreCapped() {
        let ids = Array(1...(ArchiveAvatarArt.displayLimit + 3))
        #expect(ArchiveAvatarArt.images(for: ids).count == ArchiveAvatarArt.displayLimit)
    }

    @Test("저장자가 없으면 배열이 비어 아바타 자리 자체가 사라진다")
    func absentProfileYieldsNoAvatar() {
        let absent = ArchiveAvatarArt.images(for: MemberProfile?.none)
        let present = ArchiveAvatarArt.images(for: MemberProfile(id: MemberID("u"), nickname: "나", avatarID: 2))
        #expect(absent.isEmpty)
        #expect(present.count == 1)
    }
}
