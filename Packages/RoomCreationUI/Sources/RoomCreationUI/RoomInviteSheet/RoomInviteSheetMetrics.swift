import Foundation

/// 004-4-2 친구 초대 시트의 높이 스펙(Figma `2542:125843`).
///
/// `RoomShareUI.RoomShareSheetMetrics` 와 같은 이유로 별 파일에 모은다 — 시안 값과 계산이 한자리에
/// 있으면 마크업을 읽다가 숫자의 출처를 찾아 헤매지 않는다.
///
/// **높이는 참여자 수와 무관하게 고정이다.** PRD [SYS-006] Flow B 가 "높이 424dp(**고정값**)
/// 바텀시트" 로 못박았고, Figma 도 시트(`2542:125844` 424) · 목록(`2542:125862` 176)을 고정
/// 프레임으로 그린 뒤 목록에 스크롤바(`2542:125872`)를 얹었다. 인원이 적으면 목록 아래가 비는데,
/// 그건 "시트 높이가 인원에 따라 튀지 않는다" 의 대가로 시안이 택한 모양이다.
enum RoomInviteSheetMetrics {
    /// 시안이 그린 하단 안전영역(홈 인디케이터).
    ///
    /// `presentationDetents(.height(_:))` 는 안전영역 **위쪽** 높이를 받으므로 시안 높이에서 이만큼
    /// 빼야 화면에서 시안대로 보인다(`RoomShareSheetMetrics`·`SavedRoomsSheet` 와 같은 보정).
    static let designSafeAreaBottom: CGFloat = 34

    /// 시안이 그린 시트 높이 — 프레임 812 − 시트 top 388. PRD 가 못박은 고정값이다.
    static let designSheetHeight: CGFloat = 424

    /// 목록 위 여백. 시안 176 은 이 여백을 **포함한** 영역 높이다.
    static let memberListTopPadding: CGFloat = 12

    /// 스크롤 영역 높이 — 시안 176 에서 위 여백을 뺀 값. 인원과 무관하게 고정이다.
    ///
    /// 시안은 이 높이에서 3번째 행이 잘려 "아래 더 있다"를 보여 준다(164 / 72 ≈ 2.3행).
    static let memberScrollHeight: CGFloat = 176 - memberListTopPadding

    /// `presentationDetents(.height(_:))` 에 넘길 시트 높이.
    static let detentHeight: CGFloat = designSheetHeight - designSafeAreaBottom
}
