import SwiftUI

/// 빈 상태·유도 화면에 쓰는 멀티컬러 일러스트. `Image(_:)` 로 만든다.
///
/// 아이콘(``MHIcon``)과 달리 단색 템플릿이 아니라 **원본 색 그대로** 그려지므로 `.foregroundStyle` 로
/// 틴트되지 않는다.
///
/// > 같은 일러스트를 두 패키지가 쓰기 시작하면 여기로 올린다 — `emptyRoom` 은 저장 탭 빈 상태와
/// > 공동방 생성 유도 시트가 함께 쓴다.
public enum MHIllustration: String, CaseIterable, Sendable {
    /// 공동방이 하나도 없을 때 쓰는 캐릭터 일러스트(160×160). 문 뒤의 토끼 셋.
    case emptyRoom = "emptyRoomIllustration"
    /// 봉투 뒤에서 내다보는 캐릭터. Figma `009-1 친구 초대`.
    case inviteFriends = "inviteFriendsIllustration"
    /// 저장 오류 알림 셀의 썸네일(56×56) — 회색 원 안 느낌표.
    /// 아이콘 도상이 아니라 그림이다: 시안에서 `Thumbnail` 컴포넌트의 이미지 fill 로 들어가 있다.
    case saveErrorThumbnail = "notificationSaveErrorThumbnail"
}

public extension Image {
    /// Figma 일러스트를 로드한다.
    init(_ illustration: MHIllustration) {
        self.init(illustration.rawValue, bundle: .module)
    }
}
