import Foundation

/// 004-4-2 친구 초대 시트의 높이 스펙(Figma `2542:125843`).
///
/// `RoomShareUI.RoomShareSheetMetrics` 와 같은 이유로 별 파일에 모은다 — 시안 값과 계산이 한자리에
/// 있으면 마크업을 읽다가 숫자의 출처를 찾아 헤매지 않는다.
enum RoomInviteSheetMetrics {
    /// 시안이 그린 하단 안전영역(홈 인디케이터).
    ///
    /// `presentationDetents(.height(_:))` 는 안전영역 **위쪽** 높이를 받으므로 시안 높이에서 이만큼
    /// 빼야 화면에서 시안대로 보인다(`RoomShareSheetMetrics`·`SavedRoomsSheet` 와 같은 보정).
    static let designSafeAreaBottom: CGFloat = 34

    /// 시안이 그린 시트 높이 — 프레임 812 − 시트 top 388. 참여자가 상한을 채운 상태의 값이다.
    static let designSheetHeight: CGFloat = 424

    /// 참여자 한 행의 높이 — 아바타 48 + 위아래 여백 12씩. 마크업으로 고정된 값이라 셈이 어긋날
    /// 여지가 없다.
    static let memberRowHeight: CGFloat = 72

    /// 목록 위 여백. 시안 176 은 이 여백을 **포함한** 영역 높이다.
    static let memberListTopPadding: CGFloat = 12

    /// 스크롤 영역의 **상한** 높이 — 시안 176 에서 위 여백을 뺀 값.
    ///
    /// 시안은 이 높이에서 3번째 행이 잘려 "아래 더 있다"를 보여 준다(164 / 72 ≈ 2.3행).
    static let memberScrollMaxHeight: CGFloat = 176 - memberListTopPadding

    /// 인원수에 맞는 스크롤 영역 높이 — 내용만큼 쓰고 상한에서 멈춘다.
    ///
    /// `frame(maxHeight:)` 로는 안 된다. `ScrollView` 는 주어진 공간을 다 차지해서(greedy) 인원이
    /// 한 명이어도 상한까지 늘어나 마지막 행 아래에 빈 자리가 남는다(시뮬레이터에서 확인).
    static func memberScrollHeight(count: Int) -> CGFloat {
        min(CGFloat(count) * memberRowHeight, memberScrollMaxHeight)
    }

    /// `presentationDetents(.height(_:))` 에 넘길 시트 높이.
    ///
    /// 목록이 줄어든 만큼 시트도 줄인다 — 고정하면 인원이 적을 때 마지막 행과 버튼 사이에 빈 자리가
    /// 남는다. 액션 영역 높이를 여기서 셈하지 않는 것은 그게 DesignSystem 내부값이기 때문이다.
    /// 시안 총높이에서 **목록이 줄어든 차이만** 빼면 같은 결과가 나오고 결합이 생기지 않는다.
    /// (방 개수로 full 높이가 갈리는 `RoomShareUI.RoomShareSheetMetrics` 와 같은 방식.)
    static func detentHeight(memberCount: Int) -> CGFloat {
        let shrunk = memberScrollMaxHeight - memberScrollHeight(count: memberCount)
        return designSheetHeight - designSafeAreaBottom - shrunk
    }
}
