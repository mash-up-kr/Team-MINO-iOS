import CoreGraphics
import Testing
import RoomShareUI

/// 시안 수치는 리뷰에서 눈으로 셀 수 없다 — 값이 바뀌면 여기서 걸린다.
struct RoomShareSheetMetricsTests {
    /// 진입 단계는 방이 몇 개든 같다(시안 500 − 홈 인디케이터 34).
    @Test("peek 은 방 개수와 무관하게 466")
    func peekIsFixed() {
        #expect(RoomShareSheetMetrics.peekDetentHeight == CGFloat(466))
    }

    /// 시안 676(4개)·708(4개 이상)에서 각각 34 를 뺀 값.
    @Test("full 은 방 5개부터 한 칸 커진다", arguments: [
        (roomCount: 0, expected: CGFloat(642)),
        (roomCount: 1, expected: CGFloat(642)),
        (roomCount: 3, expected: CGFloat(642)),
        (roomCount: 4, expected: CGFloat(642)),
        (roomCount: 5, expected: CGFloat(674)),
        (roomCount: 10, expected: CGFloat(674)),
    ])
    func fullByRoomCount(roomCount: Int, expected: CGFloat) {
        #expect(RoomShareSheetMetrics.fullDetentHeight(roomCount: roomCount) == expected)
    }

    /// 두 detent 가 뒤집히면 시트가 peek 에서 이미 full 만큼 커진다 — 개수가 0 일 때가 가장 아슬하다.
    @Test("full 은 언제나 peek 보다 크다", arguments: [0, 4, 5, 10])
    func fullExceedsPeek(roomCount: Int) {
        #expect(RoomShareSheetMetrics.fullDetentHeight(roomCount: roomCount)
            > RoomShareSheetMetrics.peekDetentHeight)
    }
}
