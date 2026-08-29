import DesignSystem
import Domain
import SwiftUI

/// 아바타 **프리셋 번호**(`MemberProfile.avatarID`)를 캐릭터 그림으로 잇는다.
///
/// 프로필이 그려지는 자리는 화면을 가리지 않고 모두 이 한 곳을 거친다 — 홈 카드 작성자, 방 카드,
/// 방 상세 헤더, 장소 카드 저장자, 장소 상세 공유자, 코멘트 작성자. 자리마다 따로 매핑하면 같은
/// 사람이 화면마다 다른 얼굴로 뜬다.
///
/// 번호↔캐릭터 대응은 직접 표를 들지 않고 ``AvatarPalette`` 에 위임한다. 그쪽이 이미
/// 인덱스↔색↔캐릭터 세 어휘를 잇는 단일 이음매라, 표가 둘이 되면 같은 계정이 프로필 설정
/// 화면과 다른 얼굴로 그려진다.
///
/// > **번호는 임시 계약이다.** 서버가 아바타를 실제로 주고받는 형식은 색 문자열(`avatar.color`)이고,
/// > 번호(`avatar.id`)는 `GET /api/v1/rooms/{roomId}/cards` 한 곳에서만 나온다. 방 응답(`/rooms`)은
/// > 이미 색으로 넘어가 ``AvatarPalette/images(of:)`` 를 쓴다 — 핀 응답(`/pins`)까지 실 API 로
/// > 바뀌면 남은 호출부(홈 카드 저장자·코멘트 작성자·장소 상세 공유자)도 옮기고 이 타입은 지운다.
public enum AvatarArt {
    /// 한 줄에 얼굴을 몇 개까지 늘어놓는가. 색 계약 쪽(``AvatarPalette/displayLimit``)과 같은 값이어야
    /// 번호로 그리는 자리와 색으로 그리는 자리가 화면마다 다른 인원수를 보이지 않는다.
    public static let displayLimit = AvatarPalette.displayLimit

    public static func character(for avatarID: Int) -> MHCharacter {
        // avatarID 는 1 부터다. 팔레트를 벗어난 번호(서버가 우리보다 앞서 나간 경우)는 되감아 쓴다 —
        // 빈 얼굴을 띄우는 것보다 낫고, 같은 번호는 언제나 같은 얼굴이라 화면끼리 어긋나지 않는다.
        let count = AvatarPalette.entries.count
        let index = (avatarID - 1) % count
        return AvatarPalette.character(at: index >= 0 ? index : index + count)
    }

    public static func image(for avatarID: Int) -> Image {
        Image(character(for: avatarID))
    }

    /// 아바타 그룹·스택에 넘길 이미지 배열. ``displayLimit`` 까지만 자른다.
    public static func images(for avatarIDs: [Int]) -> [Image?] {
        avatarIDs.prefix(displayLimit).map(image(for:))
    }

    /// 프로필 하나를 그룹 API(`[Image?]`)에 실을 때. 없으면 빈 배열이라 자리 자체가 사라진다 —
    /// 익명 회색 원을 대신 띄우면 "이름 모를 누군가"로 읽혀 없는 정보를 있는 것처럼 보이게 한다.
    public static func images(for profile: MemberProfile?) -> [Image?] {
        profile.map { [image(for: $0.avatarID)] } ?? []
    }
}
