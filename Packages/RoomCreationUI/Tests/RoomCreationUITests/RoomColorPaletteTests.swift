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

    // gray 는 "색 미선택" 을 표현하는 값이라 피커에 칸이 없다. 나머지 12색은 빠짐없이 있어야 한다.
    @Test("피커는 gray 를 뺀 도메인 12색을 하나도 빠짐없이 덮는다")
    func coversEveryRoomColorExceptGray() {
        #expect(Set(RoomColorPalette.entries.map(\.color)) == Set(RoomColor.allCases).subtracting([.gray]))
    }

    @Test("gray 는 그릴 썸네일이 없다 — 호출부가 my-room 으로 폴백한다")
    func grayHasNoThumbnail() {
        #expect(RoomColorPalette.thumbnail(for: .gray) == nil)
        #expect(RoomColorPalette.index(of: .gray) == nil)
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

    // 서버로 나가는 문자열이라 오타 하나가 곧 400 이다. 다중 단어는 snake_case —
    // kebab 을 보내면 "색상은 팔레트 키 중 하나여야 합니다" 로 거부된다(실측).
    @Test("서버 전송 문자열(rawValue)을 고정한다")
    func rawValuesMatchServerContract() {
        // 서버 스펙의 enum 을 그대로 옮긴 것이다. 하나라도 어긋나면 400 이라 전부 고정한다.
        #expect(Set(RoomColor.allCases.map(\.rawValue)) == [
            "red", "red_orange", "orange", "lime", "green", "cyan",
            "violet", "pink", "blue", "brown", "light_blue", "purple", "gray",
        ])
    }

    @Test("범위 밖 인덱스는 nil — 화면이 my-room 썸네일로 폴백한다")
    func outOfRangeIndexIsNil() {
        #expect(RoomColorPalette.thumbnail(at: -1) == nil)
        #expect(RoomColorPalette.thumbnail(at: 12) == nil)
        #expect(RoomColorPalette.color(at: -1) == nil)
        #expect(RoomColorPalette.color(at: 12) == nil)
    }
}
