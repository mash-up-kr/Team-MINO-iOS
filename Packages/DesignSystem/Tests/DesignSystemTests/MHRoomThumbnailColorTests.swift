import XCTest
@testable import DesignSystem

final class MHRoomThumbnailColorTests: XCTestCase {
    // 방 색 피커 12색의 fill(밝은 단계) hex → 해당 팔레트 색.
    func testFillHexMatchesColor() {
        let cases: [(String, MHRoomThumbnailColor)] = [
            ("#FF6363", .red),
            ("#FF9B61", .redOrange),
            ("#FFC06E", .orange),
            ("#AEF779", .lime),
            ("#ACFCC7", .green),
            ("#B5F4FF", .cyan),
            ("#C0B0FF", .violet),
            ("#FED3F7", .pink),
            ("#4F95FF", .blue),
            ("#DBA679", .brown),
            ("#3DC2FF", .lightBlue),
            ("#DE96FF", .purple),
        ]
        for (hex, expected) in cases {
            XCTAssertEqual(MHRoomThumbnailColor(roomColorHex: hex), expected, "\(hex) → \(expected)")
        }
    }

    // 선택 시 채움색(진한 단계) hex 로도 같은 색에 매칭된다 — 백엔드가 어느 tier 를 보내도 대응.
    func testSelectedTierHexMatchesSameColor() {
        let cases: [(String, MHRoomThumbnailColor)] = [
            ("#B00C0C", .red),
            ("#C94A00", .redOrange),
            ("#D47800", .orange),
            ("#429E00", .lime),
            ("#1ED45A", .green),
            ("#00BDDE", .cyan),
            ("#6541F2", .violet),
            ("#FA73E3", .pink),
            ("#0054D1", .blue),
            ("#B96013", .brown),
            ("#008DCF", .lightBlue),
            ("#AD36E3", .purple),
        ]
        for (hex, expected) in cases {
            XCTAssertEqual(MHRoomThumbnailColor(roomColorHex: hex), expected, "\(hex) → \(expected)")
        }
    }

    // `#` 유무·대소문자를 무시한다.
    func testHexNormalization() {
        XCTAssertEqual(MHRoomThumbnailColor(roomColorHex: "FF6363"), .red)   // # 없음
        XCTAssertEqual(MHRoomThumbnailColor(roomColorHex: "#ff6363"), .red)  // 소문자
        XCTAssertEqual(MHRoomThumbnailColor(roomColorHex: "#Ff6363"), .red)  // 혼합
    }

    // 팔레트에 없는 값은 nil — 호출부가 my-room 썸네일로 폴백한다.
    func testNonPaletteHexReturnsNil() {
        XCTAssertNil(MHRoomThumbnailColor(roomColorHex: ""))
        XCTAssertNil(MHRoomThumbnailColor(roomColorHex: "#123456"))
        XCTAssertNil(MHRoomThumbnailColor(roomColorHex: "#FEECFB"))  // 옛 Pink/95 tint — 팔레트값 아님
        XCTAssertNil(MHRoomThumbnailColor(roomColorHex: "#FF4242"))  // Red/50 — 팔레트에 없는 tier
    }
}
