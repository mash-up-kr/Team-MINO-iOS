import CoreGraphics
import Testing
@testable import SavePostUI

/// 시안 수치는 리뷰에서 눈으로 셀 수 없다 — 값이 바뀌면 여기서 걸린다.
struct SavePostSheetMetricsTests {
    /// 시안 기기(홈 인디케이터 34)에서는 스펙 원문(node 2792:175979)의 고정값이 그대로 나온다.
    @Test("단계·방 개수별 높이 — 시안 기기", arguments: [
        (detent: SavePostSheetDetent.peek, roomCount: 0, expected: CGFloat(436)),
        (detent: .peek, roomCount: 4, expected: CGFloat(436)),
        (detent: .peek, roomCount: 12, expected: CGFloat(436)),
        (detent: .full, roomCount: 0, expected: CGFloat(436)),
        (detent: .full, roomCount: 3, expected: CGFloat(436)),
        (detent: .full, roomCount: 4, expected: CGFloat(612)),
        (detent: .full, roomCount: 5, expected: CGFloat(644)),
        (detent: .full, roomCount: 12, expected: CGFloat(644)),
    ])
    func height_onDesignDevice(detent: SavePostSheetDetent, roomCount: Int, expected: CGFloat) {
        #expect(SavePostSheetMetrics.height(detent, roomCount: roomCount, safeAreaBottom: 34) == expected)
    }

    /// peek 은 방 개수와 무관하게 같은 높이다 — 개수로 갈리는 건 full 뿐(013-1 ①).
    @Test("peek 은 방 개수에 반응하지 않는다")
    func peek_isConstantAcrossRoomCounts() {
        let heights = (0...12).map { SavePostSheetMetrics.height(.peek, roomCount: $0, safeAreaBottom: 34) }
        #expect(Set(heights) == [436])
    }

    /// full 은 peek 보다 낮아질 수 없다 — 3개 이하는 스펙에 full 이 없어 같은 높이로 붙는다.
    @Test("full 은 언제나 peek 이상")
    func full_isNeverShorterThanPeek() {
        for roomCount in 0...12 {
            let peek = SavePostSheetMetrics.height(.peek, roomCount: roomCount, safeAreaBottom: 34)
            let full = SavePostSheetMetrics.height(.full, roomCount: roomCount, safeAreaBottom: 34)
            #expect(full >= peek, "roomCount=\(roomCount)")
        }
    }

    /// 홈 인디케이터가 없는 기기(SE3)에서는 버튼 아래 여백이 20 만 남아 14 낮아진다.
    /// (34 를 통째로 빼지 않는다 — 컨테이너 하단 패딩 20 은 인디케이터 유무와 무관하게 남는다.)
    @Test("하단 safe-area 가 0 이면 14 만큼 낮아진다")
    func height_withoutHomeIndicator() {
        #expect(SavePostSheetMetrics.height(.full, roomCount: 5, safeAreaBottom: 0) == CGFloat(630))
        #expect(SavePostSheetMetrics.height(.full, roomCount: 4, safeAreaBottom: 0) == CGFloat(598))
        #expect(SavePostSheetMetrics.height(.peek, roomCount: 3, safeAreaBottom: 0) == CGFloat(422))
    }

    /// 인셋이 컨테이너 하단 패딩(20)보다 작으면 패딩이 이긴다 — 버튼이 화면 바닥에 붙지 않는다.
    @Test("인셋 20 미만은 하단 패딩이 하한", arguments: [CGFloat(0), 8, 20])
    func height_clampsSmallInsets(safeAreaBottom: CGFloat) {
        #expect(SavePostSheetMetrics.height(.peek, roomCount: 0, safeAreaBottom: safeAreaBottom)
                == SavePostSheetMetrics.height(.peek, roomCount: 0, safeAreaBottom: 0))
    }

    /// 시트 높이가 아니라 **목록 뷰포트**가 시안과 맞아야 카드 장수가 맞는다.
    /// 시안 `Frame 280` 실측: peek 240 / full_4개 416(카드 4장 = 104×4) / full_4개 이상 448.
    @Test("목록 뷰포트가 시안 Frame 280 과 일치", arguments: [
        (detent: SavePostSheetDetent.peek, roomCount: 4, expected: CGFloat(240)),
        (detent: .full, roomCount: 4, expected: CGFloat(416)),
        (detent: .full, roomCount: 5, expected: CGFloat(448)),
    ])
    func listViewport_matchesDesign(detent: SavePostSheetDetent, roomCount: Int, expected: CGFloat) {
        #expect(listViewport(detent, roomCount: roomCount, safeAreaBottom: 34) == expected)
    }

    /// 액션 영역은 시안 값 102(컨테이너 88 + `Bottom Safe Area` 14)여야 한다 — 34 를 통째로 더해
    /// 122 가 되면 목록이 20 씩 줄어 612 에서 "카드 4개 전체"가 깨진다.
    @Test("액션 영역 총높이 — 시안 기기 102")
    func actionArea_matchesDesign() {
        #expect(SavePostSheetMetrics.actionAreaBottomBand(safeAreaBottom: 34) == CGFloat(14))
        #expect(SavePostSheetMetrics.actionAreaContentHeight
                + SavePostSheetMetrics.actionAreaBottomBand(safeAreaBottom: 34) == CGFloat(102))
    }

    /// 목록이 실제로 쓰는 세로 공간 — 시트 높이에서 헤더와 (액션 영역 + 그 아래 띠)를 뺀 값.
    private func listViewport(
        _ detent: SavePostSheetDetent,
        roomCount: Int,
        safeAreaBottom: CGFloat
    ) -> CGFloat {
        SavePostSheetMetrics.height(detent, roomCount: roomCount, safeAreaBottom: safeAreaBottom)
            - SavePostSheetMetrics.headerHeight
            - SavePostSheetMetrics.actionAreaContentHeight
            - SavePostSheetMetrics.actionAreaBottomBand(safeAreaBottom: safeAreaBottom)
    }
}
