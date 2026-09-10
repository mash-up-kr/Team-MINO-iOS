import Domain
import Foundation
import MapUI
import Testing
import PlaceMapUI

/// 지도 축소 시 겹치는 핀을 묶는 규칙을 고정한다.
///
/// PRD [SYS-004] Flow C — *"**지도 축소 시:** 핀이 겹치는 구간을 클러스터로 묶는다. **1~99개는
/// `50+` 식 숫자 표기 클러스터**, **100개 이상은 `100+` 클러스터** 아이콘으로 표시한다."*
///
/// 화면으로는 "핀이 몇 개 보인다" 로만 읽혀 규칙이 어긋나도 눈으로 못 잡는다 — 특히 **줌에 따라
/// 묶였다 풀리는지**는 손으로 확대해 봐야 알 수 있어 테스트가 유일한 안전망이다.
///
/// `PlaceMapUI` 가 iOS 전용이라(`DesignSystem` 의 `import UIKit`) 이 스위트는 시뮬레이터에서
/// 돈다 — 지도를 띄우지는 않지만 호스트 테스트는 아니다.
@Suite("PlaceMap 클러스터링")
struct PlaceMapClusteringTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    /// 강남 일대 — 기본 카메라 근처.
    private let origin = Coordinate(latitude: 37.4966, longitude: 127.0530)

    private func pin(_ id: String, _ coordinate: Coordinate, room: String = "r1") -> Pin {
        PinFixture.pin(
            id: PinID(id),
            roomID: room,
            category: .worthVisiting,
            title: "장소 \(id)",
            address: "주소 \(id)",
            coordinate: coordinate,
            createdAt: now
        )
    }

    /// 기준점에서 경도로 `meters` 만큼 떨어진 좌표(대략값 — 위도 37도에서 1도 ≈ 88km).
    private func east(_ meters: Double) -> Coordinate {
        Coordinate(latitude: origin.latitude, longitude: origin.longitude + meters / 88_000)
    }

    private func clustered(_ pins: [Pin], zoom: Float, selectedPinID: String? = nil) -> [MapMarker] {
        PlaceMap.clustered(
            pins: pins,
            zoom: zoom,
            roomColors: ["r1": .red, "r2": .blue],
            selectedPinID: selectedPinID,
            showsLabels: false
        )
    }

    // MARK: - 묶기

    @Test("핀이 하나면 클러스터를 만들지 않는다")
    func singlePinStaysPin() {
        let markers = clustered([pin("a", origin)], zoom: 15)

        #expect(markers.count == 1)
        #expect(markers.first?.style.kind == .pin(.red))
        #expect(markers.first?.id == "a")
    }

    // 축소하면 붙고 확대하면 갈린다 — 이 화면의 핵심 동작이다.
    @Test("멀리서는 묶이고 확대하면 갈린다")
    func clustersDependOnZoom() {
        let pins = [pin("a", origin), pin("b", east(200))]

        let far = clustered(pins, zoom: 10)
        let near = clustered(pins, zoom: 19)

        #expect(far.count == 1)
        #expect(far.first?.style.kind == .cluster(count: 2, tint: PlaceMap.tint(for: .red)))
        #expect(near.count == 2)
        #expect(near.allSatisfy { $0.style.kind == .pin(.red) })
    }

    @Test("멀리 떨어진 핀은 축소해도 각자 선다")
    func distantPinsStaySeparate() {
        // 서울 ↔ 부산 정도로 벌려 두면 어지간한 줌에서도 같은 셀에 안 들어간다.
        let pins = [
            pin("a", Coordinate(latitude: 37.5, longitude: 127.0)),
            pin("b", Coordinate(latitude: 35.1, longitude: 129.0)),
        ]

        let markers = clustered(pins, zoom: 12)

        #expect(markers.count == 2)
        #expect(markers.allSatisfy { $0.style.kind == .pin(.red) })
    }

    // MARK: - 카운트 표기

    @Test("99까지는 실제 수를 쓴다")
    func countBelowHundred() {
        #expect(PlaceMap.clusterCountText(2) == "2")
        #expect(PlaceMap.clusterCountText(50) == "50")
        #expect(PlaceMap.clusterCountText(99) == "99")
    }

    // PRD 두 갈래의 경계. 아바타 카운터(99+)와 상한이 달라 헷갈리는 자리다.
    @Test("100 이상은 100+ 로 캡한다")
    func countAtHundred() {
        #expect(PlaceMap.clusterCountText(100) == "100+")
        #expect(PlaceMap.clusterCountText(1234) == "100+")
    }

    // MARK: - 선택 핀

    // 묶이면 방금 고른 장소가 클러스터 안으로 사라져, 시트는 열려 있는데 지도에는 그 핀이 없다.
    @Test("선택된 핀은 묶지 않는다")
    func selectedPinIsNeverClustered() {
        let pins = [pin("a", origin), pin("b", east(50)), pin("c", east(80))]

        let markers = clustered(pins, zoom: 10, selectedPinID: "a")

        #expect(markers.contains { $0.id == "a" && $0.style.isSelected })
        #expect(markers.contains { PlaceMap.isClusterID($0.id) })
    }

    // MARK: - 색

    @Test("한 방의 핀만 묶이면 그 방 색을 쓴다")
    func singleRoomClusterUsesRoomColor() {
        let pins = [pin("a", origin, room: "r1"), pin("b", east(50), room: "r1")]

        let markers = clustered(pins, zoom: 10)

        #expect(markers.first?.style.kind == .cluster(count: 2, tint: PlaceMap.tint(for: .red)))
    }

    // 여러 방이 섞인 클러스터의 색은 PRD 에 없다 — 한 방 색을 임의로 고르면 그 방에만 속한
    // 것처럼 읽히므로 기본 회색으로 떨어뜨린다.
    @Test("여러 방이 섞이면 기본색으로 떨어진다")
    func mixedRoomClusterUsesDefaultTint() {
        let pins = [pin("a", origin, room: "r1"), pin("b", east(50), room: "r2")]

        let markers = clustered(pins, zoom: 10)

        #expect(markers.count == 1)
        #expect(markers.first?.style.kind == .cluster(count: 2, tint: MapMarkerStyle.defaultTint))
    }

    // MARK: - 안정성

    // 같은 줌·같은 핀이면 같은 결과여야 한다. 클러스터 id 나 순서가 흔들리면 `MarkerDiff` 가
    // 마커를 지웠다 다시 만들어 지도가 깜박인다.
    @Test("같은 입력이면 같은 마커가 같은 순서로 나온다")
    func deterministicOutput() {
        let pins = [pin("a", origin), pin("b", east(50)), pin("c", east(5_000))]

        let first = clustered(pins, zoom: 12)
        let second = clustered(pins, zoom: 12)

        #expect(first.map(\.id) == second.map(\.id))
    }

    // 카메라가 멈출 때마다 줌이 미세하게 다르면 클러스터가 계속 재구성된다.
    @Test("줌은 정수 단계로 내려 같은 단계에서 같은 결과를 낸다")
    func quantizesZoom() {
        #expect(PlaceMap.quantized(zoom: 12.0) == 12)
        #expect(PlaceMap.quantized(zoom: 12.4) == 12)
        #expect(PlaceMap.quantized(zoom: 12.9) == 12)

        let pins = [pin("a", origin), pin("b", east(200))]
        #expect(clustered(pins, zoom: 12.1).map(\.id) == clustered(pins, zoom: 12.9).map(\.id))
    }

    @Test("클러스터 id 는 접두사로 구분된다")
    func clusterIDPrefix() {
        let markers = clustered([pin("a", origin), pin("b", east(50))], zoom: 10)

        #expect(markers.count == 1)
        #expect(PlaceMap.isClusterID(markers[0].id))
        #expect(!PlaceMap.isClusterID("a"))
    }

    // 클러스터에는 어느 장소의 이름인지 정할 수 없다.
    @Test("클러스터에는 라벨을 달지 않는다")
    func clusterHasNoLabel() {
        let markers = PlaceMap.clustered(
            pins: [pin("a", origin), pin("b", east(50))],
            zoom: 10,
            roomColors: ["r1": .red],
            selectedPinID: nil,
            showsLabels: true   // 라벨을 켜도
        )

        #expect(markers.first?.title == nil)
    }

    @Test("핀이 없으면 마커도 없다")
    func noPins() {
        #expect(clustered([], zoom: 12).isEmpty)
    }
}
