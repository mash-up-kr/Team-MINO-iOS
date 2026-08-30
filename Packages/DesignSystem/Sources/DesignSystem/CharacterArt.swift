import SwiftUI

// Figma `character` 섹션(node 17055-23942)의 나머지 두 아트 세트.
//
// 같은 섹션의 홈 마스코트는 ``MHHomeMascot``(`HomeMascot.swift`)에 있다. 셋 다 축이 같다 —
// **팔레트 색 13종(black + 12색)** 이고, 케이스 이름은 Figma 배리언트 이름을 그대로 옮긴 것이다.
//
// > 어떤 색이 어떤 계정에 저장되는지는 DesignSystem 이 알지 않는다 — 서버 계약이라 화면 레이어
// > (`ProfileSetupUI.AvatarPalette`)가 잇는다(``MHCharacter``·``MHHomeMascot`` 와 같은 이유).

/// 방 커버(썸네일) 캐릭터 아트 13종 (Figma `character/RoomCover`).
///
/// 파스텔 정사각(80pt 기준 radius 14) 위에 **색칠된 토끼 실루엣** 한 장. 얼굴·소품이 없어
/// 작은 크기에서도 색이 먼저 읽힌다.
///
/// ``MHRoomThumbnail`` 이 이 아트를 그린다.
public enum MHRoomCover: String, CaseIterable, Sendable {
    /// 아바타 색을 아직 고르지 않은 계정 자리 (Figma `Property 1=black`). 회색 실루엣이다.
    case plain = "roomCoverBlack"
    case red = "roomCoverRed"
    case redOrange = "roomCoverRedOrange"
    case orange = "roomCoverOrange"
    case lime = "roomCoverLime"
    case green = "roomCoverGreen"
    case cyan = "roomCoverCyan"
    case lightBlue = "roomCoverLightBlue"
    case blue = "roomCoverBlue"
    case violet = "roomCoverViolet"
    case purple = "roomCoverPurple"
    case pink = "roomCoverPink"
    case brown = "roomCoverBrown"
}

/// 프로필 아바타 캐릭터 아트 13종 (Figma `character/Avatar Profile`).
///
/// 파스텔 원 위에 **검은 토끼 얼굴 + 색별 소품**(셰프 모자·밀짚모자·귀마개·하트 선글라스 …).
/// 몸통은 13종이 모두 같고 소품만 다르다 — ``MHHomeMascot`` 과 같은 구성이다.
///
/// > ``MHCharacter``(`character01`~`character12`) 는 **이전 세대 아트**(얼굴 있는 블롭 캐릭터)이고
/// > 화면들이 아직 그것을 그린다. 교체는 별도 작업 — 이 타입은 새 아트를 에셋에 들여놓기만 한다.
public enum MHAvatarProfile: String, CaseIterable, Sendable {
    /// 아바타 색을 아직 고르지 않은 계정 자리 (Figma `Property 1=black`). 소품이 없다.
    case plain = "avatarProfileBlack"
    case red = "avatarProfileRed"
    case redOrange = "avatarProfileRedOrange"
    case orange = "avatarProfileOrange"
    case lime = "avatarProfileLime"
    case green = "avatarProfileGreen"
    case cyan = "avatarProfileCyan"
    case lightBlue = "avatarProfileLightBlue"
    case blue = "avatarProfileBlue"
    case violet = "avatarProfileViolet"
    case purple = "avatarProfilePurple"
    case pink = "avatarProfilePink"
    case brown = "avatarProfileBrown"
}

public extension Image {
    /// 방 커버 캐릭터 아트를 로드한다. 멀티컬러 원본이라 템플릿 렌더링이 아니다.
    init(_ cover: MHRoomCover) {
        self.init(cover.rawValue, bundle: .module)
    }

    /// 프로필 아바타 캐릭터 아트를 로드한다. 멀티컬러 원본이라 템플릿 렌더링이 아니다.
    init(_ avatar: MHAvatarProfile) {
        self.init(avatar.rawValue, bundle: .module)
    }
}
