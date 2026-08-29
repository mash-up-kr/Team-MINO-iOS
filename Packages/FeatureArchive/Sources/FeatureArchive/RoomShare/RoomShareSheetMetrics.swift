import CoreGraphics

/// 다른 방에 공유 시트의 단계별 높이. Figma 스펙 시트(node `2400:268882`) ① — 값은 전부 action area 포함.
///
/// | 단계 | 방 개수 | 시안 높이 | 보이는 카드 |
/// |---|---|---|---|
/// | peek | — | 500 | 2장 + 3번째 잘림 |
/// | full | 4개 | 676 | 4장 |
/// | full | 5개 이상 | 708 | 4장 + 5번째 잘림(스크롤 어포던스) |
///
/// 높이는 **열릴 때 방 개수로 정해지고 고정된다.** 콘텐츠를 재지 않는다.
///
/// 시안 값 셋은 모두 홈 인디케이터 34 를 **포함한** 총 높이다 — 세 프레임(`2392:128669`·`2542:10516`·
/// `2392:128693`) 다 시트 아래끝이 기기 아래끝(812)과 같고 그 안에 Home Bar(34)가 든다.
/// `presentationDetents(.height(_:))` 는 하단 안전영역 **위쪽** 높이라 그만큼 뺀 값을 준다.
/// 홈 인디케이터가 없는 기기에서는 시트가 34pt 짧아지지만 목록이 그만큼 줄 뿐이라 무해하다.
///
/// > 선례 ``SavePostSheetMetrics`` 는 `height(roomCount:safeAreaBottom:)` 로 **총 높이**를 주고
/// > detent 로 쓸 때만 `safeAreaBottom: 0` 을 넘긴다 — 익스텐션에서 `.frame(height:)` 로도 쓰기
/// > 때문이다. 이 시트는 소비처가 detent 하나뿐이라 뺄셈을 여기서 끝내고 인자를 두지 않는다.
///
/// **알려진 20pt 차이**: 목록 뷰포트 = 높이 − 헤더 158 − 액션 88 이라 full_4개(642)에서 396 이 되어
/// 카드 4장(104×4 = 416)에 20 모자란다(4번째가 20 잘려 스크롤로 닿는다). 시안의 Action Area 102 는
/// 홈 인디케이터 34 를 자기 하단 여백으로 삼는데, 여기서는 `MHActionArea(safeArea: false)` 88 아래로
/// 시스템이 34 를 따로 깔아 20 이 더 먹히기 때문이다. ``SavePostSheetMetrics`` 도 같은 20 을 안고 간다.
/// 헤더 158 = 그래버 30 + 장소 60 + 새 방 56 + 구분선 12, 액션 88 = 상하 패딩 20×2 + 버튼 48(`.large`).
enum RoomShareSheetMetrics {
    /// 시안 기기의 하단 safe-area(홈 인디케이터).
    static let designSafeAreaBottom: CGFloat = 34

    /// 진입 단계 — 방 개수와 무관하게 고정이다.
    static let peekDetentHeight: CGFloat = 500 - designSafeAreaBottom

    /// 펼친 단계. 5개부터 한 칸 커져 5번째 카드가 걸쳐 보인다.
    ///
    /// 4개 **미만**은 시안에 값이 없어 "4개" 와 같이 둔다 — 남는 자리는 목록 아래 여백이 가져간다.
    /// (디자인 확인 대상. 값이 정해지면 여기 한 줄만 갈아끼운다)
    static func fullDetentHeight(roomCount: Int) -> CGFloat {
        let design: CGFloat = roomCount >= 5 ? 708 : 676
        return design - designSafeAreaBottom
    }
}
