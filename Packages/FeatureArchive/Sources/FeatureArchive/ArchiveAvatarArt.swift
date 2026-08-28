import DesignSystem
import Domain
import SwiftUI

/// 아바타 프리셋 번호(`MemberProfile.avatarID`·`RoomMember.avatarID`)를 캐릭터 그림으로 잇는다.
///
/// 아카이브의 프로필 자리는 모두 이 한 곳을 거친다 — 방 카드·방 상세 헤더·장소 카드 저장자·
/// 장소 상세 공유자·코멘트 작성자. 자리마다 따로 매핑하면 같은 사람이 화면마다 다른 얼굴로 뜬다.
///
/// > **번호는 임시 계약이다.** 서버가 아바타를 실제로 주고받는 형식은 색 문자열(`avatar.color`)이고,
/// > 번호(`avatar.id`)는 `GET /api/v1/rooms/{roomId}/cards` 한 곳에서만 나온다. 방·핀 응답이 색을
/// > 싣기 시작하면 `ProfileSetupUI.AvatarPalette.character(of:)` 로 갈아끼우고 이 파일은 지운다 —
/// > 그때가 `MHCharacter` 순서(= Figma 그리드 순서)와 색의 대응이 한 표로 합쳐지는 시점이다.
enum ArchiveAvatarArt {
    /// 한 줄에 얼굴을 몇 개까지 늘어놓는가. 넘치는 인원은 그리지 않는다(시안에 "+N" 배지가 없다).
    static let displayLimit = 5

    static func character(for avatarID: Int) -> MHCharacter {
        let all = MHCharacter.allCases
        // avatarID 는 1 부터다. 팔레트를 벗어난 번호(서버가 우리보다 앞서 나간 경우)는 되감아 쓴다 —
        // 빈 얼굴을 띄우는 것보다 낫고, 같은 번호는 언제나 같은 얼굴이라 화면끼리 어긋나지 않는다.
        let index = (avatarID - 1) % all.count
        return all[index >= 0 ? index : index + all.count]
    }

    static func image(for avatarID: Int) -> Image {
        Image(character(for: avatarID))
    }

    /// 아바타 그룹·스택에 넘길 이미지 배열. `displayLimit` 까지만 자른다.
    static func images(for avatarIDs: [Int]) -> [Image?] {
        avatarIDs.prefix(displayLimit).map(image(for:))
    }

    /// 프로필 하나를 그룹 API(`[Image?]`)에 실을 때. 없으면 빈 배열이라 자리 자체가 사라진다.
    static func images(for profile: MemberProfile?) -> [Image?] {
        profile.map { [image(for: $0.avatarID)] } ?? []
    }
}
