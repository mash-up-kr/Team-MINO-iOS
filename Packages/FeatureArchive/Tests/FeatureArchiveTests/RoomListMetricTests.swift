import DesignSystem
import SwiftUI
import XCTest
@testable import FeatureArchive

/// 시안 `003-1`·`003-2` 의 시트 높이 정책을 상수와 **실제 렌더**로 함께 고정한다.
///
/// 시안은 "헤더, 칩, … 카드 영역의 총 높이값 합산 N px(고정값)" 처럼 **합계만** 적어 두었다.
/// 조각(그래버 30 · 헤더 70 · 칩 52 · 카드 104) 중 하나만 어긋나도 합이 달라지는데, 그 어긋남은
/// 화면에서 "카드 아래로 다음 카드가 조금 비친다" 정도로만 보여 눈으로는 놓치기 쉽다.
@MainActor
final class RoomListMetricTests: XCTestCase {
    private typealias Metric = RoomListContentView.Metric

    /// 시안이 못박은 세 고정값. 조각의 합이 벗어나면 시트가 카드를 자르거나 여백을 남긴다.
    /// (003-1 ③ 개인방만 · 003-2 ① 공동방 1개 · 003-2 ② 공동방 N개)
    func testHalfMatchesFigmaFixedHeights() {
        XCTAssertEqual(Metric.half(roomCount: 1), 256)
        XCTAssertEqual(Metric.half(roomCount: 2), 360)
        XCTAssertEqual(Metric.half(roomCount: 3), 380)
    }

    /// 카드가 더 늘어도 시트는 380 에서 멈춘다 — 003-2 ② 가 "3번째 카드는 짤리게" 로 상한을 못박았다.
    func testHalfStopsGrowingBeyondThreeCards() {
        for count in 3...10 {
            XCTAssertEqual(Metric.half(roomCount: count), 380, "카드 \(count)장")
        }
    }

    /// 목록이 오기 전(0장)에도 시트는 서야 한다. 제일 낮은 단계로 떴다가 자란다.
    func testHalfBeforeLoadMatchesSingleCard() {
        XCTAssertEqual(Metric.half(roomCount: 0), Metric.half(roomCount: 1))
    }

    /// 카드 높이는 DS 컴포넌트가 정한다 — 상수를 손으로 적어 둔 값이라 렌더와 대조한다.
    /// (`MHRoomCard` 가 바뀌면 half 가 조용히 틀어지는 것을 막는다.)
    func testRoomCardHeightMatchesRender() throws {
        // 카드 높이는 썸네일 80 + 위아래 12 로 정해져 폰트 등록 여부와 무관하다(텍스트 블록 74 < 80).
        let renderer = ImageRenderer(
            content: MHRoomCard(title: "내 장소", placeCount: 0, thumbnail: .myRoom, members: [nil])
                .frame(width: 335)
        )
        renderer.scale = 1
        let size = try XCTUnwrap(renderer.uiImage, "MHRoomCard 렌더 실패").size

        XCTAssertEqual(size.height, Metric.roomCardHeight, accuracy: 0.5)
    }
}
