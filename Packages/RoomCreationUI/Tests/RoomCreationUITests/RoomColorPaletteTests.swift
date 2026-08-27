import DesignSystem
import Domain
import Testing
@testable import RoomCreationUI

/// 피커 순서와 세 표현(인덱스·도메인 색·썸네일)의 짝을 고정한다. 짝이 어긋나면 "고른 색과 저장된
/// 색이 다른" 버그가 조용히 생기는데, 그건 빌드도 다른 테스트도 통과하므로 여기서만 잡힌다.
struct RoomColorPaletteTests {
    /// (인덱스, 도메인 색, 썸네일 색) — Figma 4열×3행 순서.
    private static let expected: [(index: Int, color: RoomColor, thumbnail: MHRoomThumbnailColor)] = [
        (0, .red, .red),
        (1, .redOrange, .redOrange),
        (2, .orange, .orange),
        (3, .lime, .lime),
        (4, .green, .green),
        (5, .cyan, .cyan),
        (6, .violet, .violet),
        (7, .pink, .pink),
        (8, .blue, .blue),
        (9, .brown, .brown),
        (10, .lightBlue, .lightBlue),
        (11, .purple, .purple),
    ]

    @Test("피커는 12색이고 그리드 칸 수와 같다")
    func hasTwelveColors() {
        #expect(RoomColorPalette.entries.count == 12)
        #expect(RoomColorPalette.gridItems.count == RoomColorPalette.entries.count)
    }

    @Test("팔레트는 도메인 12색을 하나도 빠짐없이 덮는다")
    func coversEveryRoomColor() {
        #expect(Set(RoomColorPalette.entries.map(\.color)) == Set(RoomColor.allCases))
    }

    // 색을 안 고른 채 확정하면 이 색이 서버로 나간다 — 피커 첫 칸과 달라지면 "본 것과 저장된 것"이 갈린다.
    @Test("기본색은 피커 첫 칸과 같다")
    func defaultColorMatchesFirstEntry() {
        #expect(RoomColorPalette.defaultColor == RoomColorPalette.color(at: 0))
    }

    @Test("인덱스마다 정해진 썸네일 색이 나온다", arguments: expected)
    func thumbnailAtIndex(_ row: (index: Int, color: RoomColor, thumbnail: MHRoomThumbnailColor)) {
        #expect(RoomColorPalette.thumbnail(at: row.index) == row.thumbnail)
    }

    @Test("인덱스마다 정해진 도메인 색이 나온다", arguments: expected)
    func colorAtIndex(_ row: (index: Int, color: RoomColor, thumbnail: MHRoomThumbnailColor)) {
        #expect(RoomColorPalette.color(at: row.index) == row.color)
    }

    // 편집 진입이 방의 색을 피커 인덱스로 되돌릴 때 쓰는 경로다.
    @Test("도메인 색은 같은 인덱스로 되돌아온다", arguments: expected)
    func indexOfColor(_ row: (index: Int, color: RoomColor, thumbnail: MHRoomThumbnailColor)) {
        #expect(RoomColorPalette.index(of: row.color) == row.index)
    }

    @Test("도메인 색 → 썸네일 색 매핑이 팔레트 순서와 일치한다", arguments: expected)
    func thumbnailForColor(_ row: (index: Int, color: RoomColor, thumbnail: MHRoomThumbnailColor)) {
        #expect(RoomColorPalette.thumbnail(for: row.color) == row.thumbnail)
    }

    @Test("범위 밖 인덱스는 nil — 화면이 my-room 썸네일로 폴백한다")
    func outOfRangeIndexIsNil() {
        #expect(RoomColorPalette.thumbnail(at: -1) == nil)
        #expect(RoomColorPalette.thumbnail(at: 12) == nil)
        #expect(RoomColorPalette.color(at: -1) == nil)
        #expect(RoomColorPalette.color(at: 12) == nil)
    }
}
