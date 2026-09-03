import SwiftUI
import Testing
@testable import FeatureArchive

/// 헤더 케밥 드롭다운의 자리 계산. 뷰 밖 순수 값이라 시안 실측치로 고정해 둔다.
///
/// 이 계산이 뷰 안에 있고 카드 높이 측정에 기대던 동안 **peek 에서만** 메뉴가 안 떴다 —
/// 그 회귀를 다시 만들지 않도록 "위로 펼 때 측정값 없이 자리가 정해진다" 를 여기서 못박는다.
struct RoomDetailMoreMenuPlacementTests {
    /// 시안 `4566:95951`(004-1-1 peek) 실측 — 케밥 y 644~684, x 267~307.
    private let peekKebab = CGRect(x: 267, y: 644, width: 40, height: 40)
    /// 시안 `2542:125383`(004-1-2 half) 실측 — 케밥 y 408~448, x 267~307.
    private let halfKebab = CGRect(x: 267, y: 408, width: 40, height: 40)

    @Test("peek — 카드 아래끝이 케밥 위 8pt 에 선다 (시안 카드 bottom 635, 실측 오차 1pt)")
    func above() {
        let placement = RoomDetailMoreMenuPlacement(kebab: peekKebab, opensUpward: true, gap: 8)

        #expect(placement.boxHeight == 636)          // 카드 아래끝 = 케밥 top 644 − 8
        #expect(placement.alignment == .bottomTrailing)
        #expect(placement.offsetY == 0)
    }

    @Test("half — 카드 윗끝이 케밥 아래 8pt 에 선다 (시안 카드 top 456)")
    func below() {
        let placement = RoomDetailMoreMenuPlacement(kebab: halfKebab, opensUpward: false, gap: 8)

        #expect(placement.offsetY == 456)            // 케밥 bottom 448 + 8
        #expect(placement.alignment == .topTrailing)
        // 아래로 펼 때는 카드 높이를 그대로 쓴다 — 재서 맞출 게 없다.
        #expect(placement.boxHeight == nil)
    }

    @Test("어느 방향이든 오른쪽 끝은 케밥 오른쪽 끝에 맞는다 (시안 카드 x 167~307)")
    func trailingEdge() {
        #expect(RoomDetailMoreMenuPlacement(kebab: peekKebab, opensUpward: true, gap: 8).boxWidth == 307)
        #expect(RoomDetailMoreMenuPlacement(kebab: halfKebab, opensUpward: false, gap: 8).boxWidth == 307)
    }

    @Test("케밥이 화면 맨 위에 붙어도 상자 높이가 음수로 내려가지 않는다")
    func aboveClampsToZero() {
        let placement = RoomDetailMoreMenuPlacement(
            kebab: CGRect(x: 267, y: 0, width: 40, height: 40),
            opensUpward: true,
            gap: 8
        )

        #expect(placement.boxHeight == 0)
    }
}
