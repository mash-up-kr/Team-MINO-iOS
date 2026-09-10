import CoreGraphics
import Testing
import UIKit
@testable import MapUI

/// 지도 핀 아트 26장(Figma `character/Pin`)이 MapUI 번들에서 실제로 풀리고, 핀 끝 앵커가 실측값과
/// 맞는지 고정한다.
///
/// MapUI 자체 테스트는 macOS 호스트에서 돌아 `UIImage` 를 만들 수 없다. 이 스위트는 MapUI 를
/// 의존하는 가장 가까운 iOS 러너(PlaceMapUITests, 시뮬레이터)에 두고 `@testable import` 로
/// `MarkerIcon` 을 본다.
///
/// 앵커 기대값은 에셋을 8배로 래스터라이즈해 알파 ≥ 0.5 최하단점을 잰 실측이다 — `MarkerIcon.tip(of:)`
/// 와 **다른 도구**(AppKit)로 잰 값이라 측정 코드가 틀려도 여기서 걸린다.
@Suite("지도 핀 아트 — 에셋·앵커")
struct MapMarkerArtTests {
    private func image(_ color: MapMarkerColor, selected: Bool) throws -> UIImage {
        try #require(
            MarkerIcon.asset(color.assetName(selected: selected)),
            "에셋 누락: \(color.assetName(selected: selected))"
        )
    }

    // 에셋 이름을 접두사+접미사로 조립하므로, 조합 하나라도 어긋나면 그 색·상태만 조용히 빈다.
    @Test("13색 × 기본/선택 26 조합이 전부 번들에서 풀린다", arguments: MapMarkerColor.allCases)
    func everyCombinationResolves(color: MapMarkerColor) throws {
        _ = try image(color, selected: false)
        _ = try image(color, selected: true)
    }

    @Test("기본 핀은 42×48, 선택 핀은 56×61 이다 — cyan 선택 핀만 귀마개 때문에 58 폭", arguments: MapMarkerColor.allCases)
    func canvasSizes(color: MapMarkerColor) throws {
        #expect(try image(color, selected: false).size == CGSize(width: 42, height: 48))
        let activeWidth: CGFloat = color == .cyan ? 58 : 56
        #expect(try image(color, selected: true).size == CGSize(width: activeWidth, height: 61))
    }

    // 기본 핀: 끝점 (20.9, 42.6) / 42×48. 아래쪽은 그림자 filter 자리라 비어 있다.
    @Test("기본 핀 끝점은 가로 가운데, 높이의 0.888 이다", arguments: MapMarkerColor.allCases)
    func defaultPinTip(color: MapMarkerColor) throws {
        let tip = MarkerIcon.tip(of: try image(color, selected: false))
        #expect(abs(tip.x - 0.5) < 0.02)
        #expect(abs(tip.y - 0.888) < 0.015)
    }

    // 선택 핀: 끝점이 바닥(61)에 닿는다 — cyan 만 57.5 로 떠 있어 상수로는 3.5pt 어긋난다.
    @Test("선택 핀 끝점은 바닥이고, cyan 만 0.943 으로 떠 있다", arguments: MapMarkerColor.allCases)
    func activePinTip(color: MapMarkerColor) throws {
        let tip = MarkerIcon.tip(of: try image(color, selected: true))
        #expect(abs(tip.x - 0.5) < 0.02)
        let expectedY: CGFloat = color == .cyan ? 0.943 : 1.0
        #expect(abs(tip.y - expectedY) < 0.015)
    }

    // 스타일 하나로 그림·앵커를 한 번에 받는다 — 라벨이 없으면 에셋 그대로, 캐시에 남는다.
    @Test("스타일에서 그림과 앵커를 함께 만들고 캐시한다")
    func artIsCached() throws {
        var cache: [MapMarkerStyle: MarkerIcon.MarkerArt] = [:]
        let style = MapMarkerStyle(kind: .pin(.red), isSelected: true)

        let art = try #require(MarkerIcon.art(for: style, label: [], cache: &cache))

        #expect(art.image.size == CGSize(width: 56, height: 61))
        #expect(abs(art.groundAnchor.y - 1.0) < 0.015)
        #expect(cache[style] != nil)
    }

    // 라벨을 붙여도 정렬 사각형을 핀 글리프로 좁히므로 앵커 비율은 그대로다.
    @Test("라벨을 붙여도 앵커는 핀에서 잰 값 그대로다")
    func labelKeepsAnchor() throws {
        var cache: [MapMarkerStyle: MarkerIcon.MarkerArt] = [:]
        let style = MapMarkerStyle(kind: .pin(.blue))

        let plain = try #require(MarkerIcon.art(for: style, label: [], cache: &cache))
        let labeled = try #require(MarkerIcon.art(for: style, label: ["도토리 용산점"], cache: &cache))

        #expect(labeled.groundAnchor == plain.groundAnchor)
        #expect(labeled.image.size.height > plain.image.size.height)
    }

    @Test("클러스터는 원 가운데를 가리키고 라벨을 달지 않는다")
    func clusterArt() throws {
        var cache: [MapMarkerStyle: MarkerIcon.MarkerArt] = [:]
        let style = MapMarkerStyle(kind: .cluster(count: 3, tint: .red))

        let art = try #require(MarkerIcon.art(for: style, label: ["무시되는 라벨"], cache: &cache))

        #expect(art.groundAnchor == CGPoint(x: 0.5, y: 0.5))
        #expect(art.image.size.height == 44)
    }
}
