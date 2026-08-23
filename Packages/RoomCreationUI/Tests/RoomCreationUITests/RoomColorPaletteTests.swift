import DesignSystem
import Testing
@testable import RoomCreationUI

/// 피커 순서를 고정한다. 순서가 바뀌면 "고른 색과 미리보기 썸네일이 다른" 버그가 조용히 생기는데,
/// 그건 빌드도 다른 테스트도 통과하므로 여기서만 잡힌다.
struct RoomColorPaletteTests {
    /// (인덱스, 채움 hex, 테두리 hex, 썸네일 색) — Figma 4열×3행 순서. `AtomicColor.xcassets` 실측값.
    private static let expected: [(index: Int, fill: String, border: String, thumbnail: MHRoomThumbnailColor)] = [
        (0, "FF6363", "E52222", .red),
        (1, "FF9B61", "C94A00", .redOrange),
        (2, "FFC06E", "D47800", .orange),
        (3, "AEF779", "429E00", .lime),
        (4, "ACFCC7", "009632", .green),
        (5, "B5F4FF", "0098B2", .cyan),
        (6, "C0B0FF", "6541F2", .violet),
        (7, "FED3F7", "FA73E3", .pink),
        (8, "4F95FF", "0054D1", .blue),
        (9, "DBA679", "B96013", .brown),
        (10, "3DC2FF", "008DCF", .lightBlue),
        (11, "DE96FF", "AD36E3", .purple),
    ]

    @Test("피커는 12색이고 그리드 칸 수와 같다")
    func hasTwelveColors() {
        #expect(RoomColorPalette.entries.count == 12)
        #expect(RoomColorPalette.gridItems.count == RoomColorPalette.entries.count)
    }

    @Test("인덱스마다 정해진 썸네일 색이 나온다", arguments: expected)
    func thumbnailAtIndex(_ row: (index: Int, fill: String, border: String, thumbnail: MHRoomThumbnailColor)) {
        #expect(RoomColorPalette.thumbnail(at: row.index) == row.thumbnail)
    }

    // 백엔드가 채움·테두리 어느 쪽 hex 를 보내도 같은 칸으로 돌아와야 한다(MHRoomThumbnail 팔레트 계약).
    @Test("방 색 hex 는 채움·테두리 둘 다 같은 인덱스로 되돌아온다", arguments: expected)
    func indexOfHex(_ row: (index: Int, fill: String, border: String, thumbnail: MHRoomThumbnailColor)) {
        #expect(RoomColorPalette.index(ofHex: row.fill) == row.index)
        #expect(RoomColorPalette.index(ofHex: row.border) == row.index)
    }

    @Test("hex 는 # 유무·대소문자를 가리지 않는다")
    func indexOfHex_isLenient() {
        #expect(RoomColorPalette.index(ofHex: "#ff6363") == 0)
        #expect(RoomColorPalette.index(ofHex: "FF6363") == 0)
    }

    @Test("팔레트 밖의 값은 nil — 화면이 my-room 썸네일로 폴백한다")
    func outOfPaletteIsNil() {
        #expect(RoomColorPalette.index(ofHex: "123456") == nil)
        #expect(RoomColorPalette.index(ofHex: "") == nil)
        #expect(RoomColorPalette.thumbnail(at: -1) == nil)
        #expect(RoomColorPalette.thumbnail(at: 12) == nil)
    }
}
