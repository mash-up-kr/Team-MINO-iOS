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
        let markers = ArchiveMap.markers(pins: pins, roomColor: .red, selectedPinID: nil)

        #expect(markers.map(\.id) == ["a", "b"])
        #expect(markers.map(\.coordinate) == [
            MapCoordinate(latitude: 37.5, longitude: 127.0),
            MapCoordinate(latitude: 37.6, longitude: 127.1),
        ])
        #expect(markers.map(\.title) == ["장소 a", "장소 b"])
    }

    @Test("핀이 없으면 마커도 없다")
    func noPinsNoMarkers() {
        #expect(ArchiveMap.markers(pins: [], roomColor: .red, selectedPinID: nil).isEmpty)
    }

    @Test("마커 색은 방 색을 따른다")
    func tintFollowsRoomColor() {
        let markers = ArchiveMap.markers(pins: [pin("a", lat: 37.5, lng: 127.0)], roomColor: .blue, selectedPinID: nil)
        #expect(markers.first?.style.tint == ArchiveMap.tint(for: .blue))
    }

    @Test("열려 있는 핀의 마커만 선택 상태다")
    func onlyOpenPinIsSelected() {
        let pins = [pin("a", lat: 37.5, lng: 127.0), pin("b", lat: 37.6, lng: 127.1)]
        let markers = ArchiveMap.markers(pins: pins, roomColor: .red, selectedPinID: "b")
        #expect(markers.map(\.style.isSelected) == [false, true])
    }

    @Test("선택된 핀이 목록에 없으면 아무 마커도 선택되지 않는다 — 방을 옮기면 이전 선택이 남는다")
    func staleSelectionSelectsNothing() {
        let pins = [pin("a", lat: 37.5, lng: 127.0)]
        let markers = ArchiveMap.markers(pins: pins, roomColor: .red, selectedPinID: "다른-방-핀")
        #expect(markers.allSatisfy { !$0.style.isSelected })
    }

    @Test("선택해도 마커 색 값은 그대로다 — 바뀌는 것은 아이콘 형식뿐이다")
    func selectionDoesNotChangeTint() {
        let pins = [pin("a", lat: 37.5, lng: 127.0)]
        let markers = ArchiveMap.markers(pins: pins, roomColor: .blue, selectedPinID: "a")
        #expect(markers.first?.style.tint == ArchiveMap.tint(for: .blue))
    }

    @Test("색 없는 방은 마커 기본색을 쓴다 — 시안의 색 없는 핀과 같은 회색")
    func noColorUsesMarkerDefault() {
        #expect(ArchiveMap.tint(for: nil) == MapMarkerStyle.defaultTint)
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

    // MARK: - 탭

    @Test("마커 탭은 그 핀 id 를 올려 보낸다")
    func markerTapCarriesPinID() {
        #expect(ArchiveMap.tappedPinID(in: .didTapMarker(id: "a")) == "a")
    }

    @Test("빈 곳 탭·카메라 이동은 장소를 열지 않는다 — 지도를 움직였다고 시트가 바뀌면 안 된다")
    func otherEventsDoNotSelect() {
        let coordinate = MapCoordinate(latitude: 37.5, longitude: 127.0)
        #expect(ArchiveMap.tappedPinID(in: .didTap(coordinate)) == nil)
        #expect(ArchiveMap.tappedPinID(in: .didIdleAt(MapCameraPosition(coordinate: coordinate, zoom: 15))) == nil)
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

    // MARK: - 현위치 (005-1)

    @Test("현위치가 서 있으면 핀 맞춤 대신 그 자리를 비춘다 — 방금 사용자가 낸 요청이다")
    func myLocationBeatsPinFit() {
        let pins = [pin("a", lat: 37.5, lng: 127.0), pin("b", lat: 37.6, lng: 127.1)]
        let me = Coordinate(latitude: 37.5443, longitude: 127.0557)

        #expect(ArchiveMap.camera(for: pins, focusing: me) == .position(
            MapCameraPosition(
                coordinate: MapCoordinate(latitude: 37.5443, longitude: 127.0557),
                zoom: ArchiveMap.myLocationZoom
            )
        ))
    }

    @Test("핀이 없어도 현위치로 간다 — 기본 카메라(강남)에 머물지 않는다")
    func myLocationWithoutPins() {
        let me = Coordinate(latitude: 37.5443, longitude: 127.0557)
        #expect(ArchiveMap.camera(for: [], focusing: me) != .position(ArchiveMap.defaultCamera))
    }

    @Test("현위치가 없으면 지금까지와 같다 — 핀에 맞춘다")
    func withoutMyLocationFallsBackToFit() {
        let pins = [pin("a", lat: 37.5, lng: 127.0)]
        #expect(ArchiveMap.camera(for: pins, focusing: nil) == ArchiveMap.camera(for: pins))
    }
}

@Suite("ArchiveMapButtonMetrics — 지도 위 부유 버튼 줄의 자리(005-1 `2792:142415`)")
struct ArchiveMapButtonMetricsTests {
    /// 시안 프레임 폭.
    private let designWidth: CGFloat = 375

    @Test("현위치 버튼은 시안 자리에 선다 — x 315..355")
    func myLocationHorizontalPlacement() {
        let right = designWidth - ArchiveMapButtonMetrics.trailing
        #expect(right == 355)
        #expect(right - ArchiveMapButtonMetrics.myLocationSize == 315)
    }

    @Test("'저장된 방' 은 현위치 왼쪽으로 물러난다 — 오른쪽 끝 307(시안), 화면 끝에서 68")
    func savedRoomsHorizontalPlacement() {
        let right = designWidth
            - ArchiveMapButtonMetrics.trailing
            - ArchiveMapButtonMetrics.myLocationSize
            - ArchiveMapButtonMetrics.spacing

        #expect(right == 307)
        #expect(designWidth - right == 68)
    }

    @Test("버튼 줄은 시트 윗끝에서 18 띄운다 — 시안 시트 441, '저장된 방' 아래끝 423")
    func bottomGapFromSheetTop() {
        let designSheetTop: CGFloat = 441
        let designSavedRoomsBottom: CGFloat = 423
        #expect(ArchiveMapButtonMetrics.bottomGap == designSheetTop - designSavedRoomsBottom)
    }
}
