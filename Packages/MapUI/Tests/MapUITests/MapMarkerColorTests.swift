import Testing
@testable import MapUI

/// 핀 아트 에셋 이름 조립 규칙. 이름을 접두사+접미사로 만들기 때문에 한 조합이 어긋나면 그 색·상태만
/// 조용히 빈다 — 에셋이 실제로 풀리는지는 `PlaceMapUITests/MapMarkerArtTests`(시뮬레이터)가 보고,
/// 여기(macOS 호스트)서는 이름 규칙만 고정한다.
@Suite("MapMarkerColor — 에셋 이름")
struct MapMarkerColorTests {
    @Test("13색 × 2상태 = 26 이름이 모두 다르다")
    func namesAreDistinct() {
        let names = MapMarkerColor.allCases.flatMap { color in
            [color.assetName(selected: false), color.assetName(selected: true)]
        }
        #expect(Set(names).count == 26)
    }

    @Test("기본 핀은 pinDefault, 선택 핀은 pinActive 로 시작한다 — Figma mode 배리언트 off/on")
    func prefixFollowsSelection() {
        for color in MapMarkerColor.allCases {
            #expect(color.assetName(selected: false).hasPrefix("pinDefault"))
            #expect(color.assetName(selected: true).hasPrefix("pinActive"))
        }
    }

    @Test("접미사는 Figma 배리언트 이름이다 — 색 없음만 Black")
    func suffixes() {
        #expect(MapMarkerColor.plain.assetName(selected: false) == "pinDefaultBlack")
        #expect(MapMarkerColor.redOrange.assetName(selected: true) == "pinActiveRedOrange")
        #expect(MapMarkerColor.lightBlue.assetName(selected: false) == "pinDefaultLightBlue")
    }

    @Test("기본 스타일은 색 없는 기본 핀이다")
    func defaultStyle() {
        #expect(MapMarkerStyle.default == MapMarkerStyle(kind: .pin(.plain), isSelected: false))
    }
}
