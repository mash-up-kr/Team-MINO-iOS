import CoreGraphics

/// 링크 저장 시트의 높이 규칙. Figma 스펙 시트(node 2792:175979) — 값은 전부 action area 포함.
///
/// 높이는 **열릴 때 방 개수로 정해지고 고정된다.** 콘텐츠를 재지 않고, 도중에 단계가 바뀌지도 않는다.
///
/// | 방 개수 | 높이 | 보이는 카드 |
/// |---|---|---|
/// | 3개 이하 | 436 | 2장 + 3번째 잘림 |
/// | 4개 | 612 | 4장(마지막 장 아래 20 잘림 — 스크롤로 닿는다) |
/// | 5개 이상 | 644 | 4장 + 5번째 잘림(스크롤 어포던스) |
///
/// 시안 값은 홈 인디케이터 34 를 포함하므로 실제 기기의 하단 safe-area 로 갈아끼운다.
/// 남는 공간은 목록이 가져간다 — 목록 뷰포트 = 높이 − 헤더 94 − 액션 88 − safe 34.
/// 헤더 94 = 그래버 30 + 텍스트 52(28+4+20) + 하단 12, 액션 88 = 상하 패딩 20×2 + 버튼 48(`MHButton` large).
/// 644 → 428 = 카드 4장(104×4) + 12. 612 → 396 이라 4장(416)에 20 모자란다.
enum SaveLinkSheetMetrics {
    static let designSafeAreaBottom: CGFloat = 34

    static func height(roomCount: Int, safeAreaBottom: CGFloat) -> CGFloat {
        let design: CGFloat = switch roomCount {
        case 5...: 644
        case 4: 612
        default: 436
        }
        return design - designSafeAreaBottom + safeAreaBottom
    }
}
