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

    /// 시트 높이 — 시안 424(= 프레임 812 − 시트 top 388)에서 안전영역을 뺀 값.
    static let detentHeight: CGFloat = 424 - designSafeAreaBottom

    /// 참여자 목록 영역의 **상한** 높이.
    ///
    /// 시안은 176 에서 3번째 행이 잘려 "아래 더 있다"를 보여 준다(행 = 아바타 48 + py12×2 = 72 →
    /// 176 / 72 ≈ 2.4행). 고정이 아니라 상한인 이유는 인원이 적을 때다 — 고정하면 마지막 행 아래로
    /// 빈 자리가 생기고 액션 영역이 시안보다 내려간다.
    static let memberListMaxHeight: CGFloat = 176
}
