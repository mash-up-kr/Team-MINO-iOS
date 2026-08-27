import Foundation
import MapUI
import Testing
import Domain
@testable import FeatureArchive

@Suite("ArchiveMap — 방 핀을 지도 마커·카메라로 옮긴다")
struct ArchiveMapLayerTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func pin(_ id: String, lat: Double, lng: Double) -> Pin {
        PinFixture.pin(
            id: PinID(id),
            roomID: "r1",
            category: .worthVisiting,
            title: "장소 \(id)",
            address: "주소 \(id)",
            coordinate: Coordinate(latitude: lat, longitude: lng),
            createdAt: now
        )
    }

    // MARK: - 마커

    @Test("핀마다 마커 하나 — id·좌표·이름을 그대로 옮긴다")
    func markersFromPins() {
        let pins = [pin("a", lat: 37.5, lng: 127.0), pin("b", lat: 37.6, lng: 127.1)]
        let markers = ArchiveMap.markers(pins: pins, roomColor: .red)

        #expect(markers.map(\.id) == ["a", "b"])
        #expect(markers.map(\.coordinate) == [
            MapCoordinate(latitude: 37.5, longitude: 127.0),
            MapCoordinate(latitude: 37.6, longitude: 127.1),
        ])
        #expect(markers.map(\.title) == ["장소 a", "장소 b"])
    }

    @Test("핀이 없으면 마커도 없다")
    func noPinsNoMarkers() {
        #expect(ArchiveMap.markers(pins: [], roomColor: .red).isEmpty)
    }

    @Test("마커 색은 방 색을 따른다")
    func tintFollowsRoomColor() {
        let markers = ArchiveMap.markers(pins: [pin("a", lat: 37.5, lng: 127.0)], roomColor: .blue)
        #expect(markers.first?.style.tint == ArchiveMap.tint(for: .blue))
    }

    @Test("색 미선택(gray)은 색이 없는 방(nil)과 같은 기본색으로 떨어진다")
    func grayFallsBack() {
        #expect(ArchiveMap.tint(for: .gray) == ArchiveMap.tint(for: nil))
    }

    @Test("12색은 서로 다른 색으로 짝지어진다 — 한 색이 다른 색을 덮어쓰면 방 구분이 사라진다")
    func paletteIsDistinct() {
        // gray 는 "색 미선택" 이라 팔레트 밖이다(기본색으로 폴백).
        let picked = RoomColor.allCases.filter { $0 != .gray }
        let tints = Set(picked.map { ArchiveMap.tint(for: $0) })
        #expect(tints.count == picked.count)
    }

    // MARK: - 카메라

    @Test("핀이 없으면 기본 카메라를 유지한다")
    func defaultCameraWithoutPins() {
        #expect(ArchiveMap.camera(for: []) == .position(ArchiveMap.defaultCamera))
    }

    @Test("핀이 있으면 전부 보이도록 맞춘다")
    func fitCameraWithPins() {
        let pins = [pin("a", lat: 37.5, lng: 127.0), pin("b", lat: 37.6, lng: 127.1)]
        #expect(ArchiveMap.camera(for: pins) == .fit(
            coordinates: [
                MapCoordinate(latitude: 37.5, longitude: 127.0),
                MapCoordinate(latitude: 37.6, longitude: 127.1),
            ],
            padding: ArchiveMap.fitPadding
        ))
    }
}
