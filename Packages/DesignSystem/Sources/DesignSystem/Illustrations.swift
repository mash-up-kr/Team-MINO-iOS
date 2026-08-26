import SwiftUI

/// 빈 상태·유도 화면에 쓰는 멀티컬러 일러스트. `Image(_:)` 로 만든다.
///
/// 아이콘(``MHIcon``)과 달리 단색 템플릿이 아니라 **원본 색 그대로** 그려지므로 `.foregroundStyle` 로
/// 틴트되지 않는다.
///
/// > 같은 일러스트를 두 패키지가 쓰기 시작하면 여기로 올린다 — `emptyRoom` 은 저장 탭 빈 상태와
/// > 공동방 생성 유도 시트가 함께 쓴다.
public enum MHIllustration: String, CaseIterable, Sendable {
    /// 공동방이 하나도 없을 때 쓰는 캐릭터 일러스트.
    case emptyRoom = "emptyRoomIllustration"
    /// 친구를 부르는 캐릭터 3인 + 폰. Figma `009-1 친구 초대`.
    case inviteFriends = "inviteFriendsIllustration"
    /// 화면 하단에 까는 구름 배경(375×325). 가로를 채우고 하단에 붙인다.
    ///
    /// 지금 쓰는 곳은 친구초대뿐이지만 DesignSystem 에 둔다 — RoomCreationUI 는
    /// FeatureOnboarding 번들에 접근할 수 없어 여기 있어야 로드된다.
    case cloudBackground
}

public extension Image {
    /// Figma 일러스트를 로드한다.
    init(_ illustration: MHIllustration) {
        self.init(illustration.rawValue, bundle: .module)
    }
}
