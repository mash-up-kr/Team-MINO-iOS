import Foundation
import MapUI
import Testing
import Domain
import PlaceMapUI

@Suite("PlaceMap — 방 핀을 지도 마커·카메라로 옮긴다")
struct PlaceMapLayerTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func pin(_ id: String, lat: Double, lng: Double, room: String = "r1") -> Pin {
        PinFixture.pin(
            id: PinID(id),
            roomID: room,
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
        let markers = PlaceMap.markers(pins: pins, roomColors: ["r1": .red], selectedPinID: nil)

        #expect(markers.map(\.id) == ["a", "b"])
        #expect(markers.map(\.coordinate) == [
            MapCoordinate(latitude: 37.5, longitude: 127.0),
            MapCoordinate(latitude: 37.6, longitude: 127.1),
        ])
        #expect(markers.map(\.title) == ["장소 a", "장소 b"])
    }

    @Test("핀이 없으면 마커도 없다")
    func noPinsNoMarkers() {
        #expect(PlaceMap.markers(pins: [], roomColors: ["r1": .red], selectedPinID: nil).isEmpty)
    }

    @Test("마커 색은 방 색을 따른다")
    func tintFollowsRoomColor() {
        let markers = PlaceMap.markers(pins: [pin("a", lat: 37.5, lng: 127.0)], roomColors: ["r1": .blue], selectedPinID: nil)
        #expect(markers.first?.style.tint == PlaceMap.tint(for: .blue))
    }

    // PRD [SYS-004] — "[SCR-004] 방 리스트 탭: 내 모든 방의 장소 마커를 한 지도에 표시하며,
    // **각 마커는 소속 방의 대표 색상을 따른다**". 방 하나짜리 화면(방 상세)만 있던 시절엔
    // 색이 전부 같았다.
    @Test("여러 방의 핀이 섞이면 마커마다 소속 방 색을 쓴다")
    func tintIsPerRoom() {
        let pins = [
            pin("a", lat: 37.5, lng: 127.0, room: "r1"),
            pin("b", lat: 37.6, lng: 127.1, room: "r2"),
        ]

        let markers = PlaceMap.markers(pins: pins, roomColors: ["r1": .red, "r2": .blue], selectedPinID: nil)

        #expect(markers.map(\.style.tint) == [PlaceMap.tint(for: .red), PlaceMap.tint(for: .blue)])
    }

    // 방 목록보다 핀이 먼저 도착할 수 있다(둘을 병렬로 받는다) — 그때 마커가 사라지면 안 된다.
    @Test("표에 없는 방의 핀은 사라지지 않고 기본색으로 선다")
    func unknownRoomFallsBackToDefault() {
        let markers = PlaceMap.markers(
            pins: [pin("a", lat: 37.5, lng: 127.0, room: "모르는-방")],
            roomColors: ["r1": .red],
            selectedPinID: nil
        )

        #expect(markers.count == 1)
        #expect(markers.first?.style.tint == MapMarkerStyle.defaultTint)
    }

    @Test("열려 있는 핀의 마커만 선택 상태다")
    func onlyOpenPinIsSelected() {
        let pins = [pin("a", lat: 37.5, lng: 127.0), pin("b", lat: 37.6, lng: 127.1)]
        let markers = PlaceMap.markers(pins: pins, roomColors: ["r1": .red], selectedPinID: "b")
        #expect(markers.map(\.style.isSelected) == [false, true])
    }

    @Test("선택된 핀이 목록에 없으면 아무 마커도 선택되지 않는다 — 방을 옮기면 이전 선택이 남는다")
    func staleSelectionSelectsNothing() {
        let pins = [pin("a", lat: 37.5, lng: 127.0)]
        let markers = PlaceMap.markers(pins: pins, roomColors: ["r1": .red], selectedPinID: "다른-방-핀")
        #expect(markers.allSatisfy { !$0.style.isSelected })
    }

    @Test("선택해도 마커 색 값은 그대로다 — 바뀌는 것은 아이콘 형식뿐이다")
    func selectionDoesNotChangeTint() {
        let pins = [pin("a", lat: 37.5, lng: 127.0)]
        let markers = PlaceMap.markers(pins: pins, roomColors: ["r1": .blue], selectedPinID: "a")
        #expect(markers.first?.style.tint == PlaceMap.tint(for: .blue))
    }

    // MARK: - 라벨 줌 게이트

    // 멀리서는 핀이 촘촘해 이름끼리 겹쳐 읽히지 않고, 화면에 뜨는 마커마다 그림을 합성하는
    // 비용도 커진다. 그래서 라벨은 확대 상태에서만 그린다.
    @Test("기본 줌 이상이면 라벨을 그린다")
    func showsLabelsWhenZoomedIn() {
        #expect(PlaceMap.showsLabels(atZoom: PlaceMap.labelZoomThreshold))
        #expect(PlaceMap.showsLabels(atZoom: PlaceMap.labelZoomThreshold + 3))
    }

    @Test("임계값보다 멀면 라벨을 그리지 않는다")
    func hidesLabelsWhenZoomedOut() {
        #expect(!PlaceMap.showsLabels(atZoom: PlaceMap.labelZoomThreshold - 0.1))
        #expect(!PlaceMap.showsLabels(atZoom: 5))
    }

    // 카메라 idle 을 받기 전(진입 직후)에는 기본 카메라 줌으로 판단한다 — 그 줌이 임계값이라
    // 진입 상태에서 라벨이 보인다.
    @Test("줌을 아직 모르면 기본 카메라 줌으로 판단한다")
    func unknownZoomUsesDefault() {
        #expect(PlaceMap.showsLabels(atZoom: nil) == (PlaceMap.defaultCamera.zoom >= PlaceMap.labelZoomThreshold))
        #expect(PlaceMap.showsLabels(atZoom: nil))
    }

    // 라벨을 끄면 `title` 을 비워 보낸다 — `MapView` 는 받은 값을 그리기만 하므로 판단이
    // 순수 계산부에 남는다.
    @Test("라벨을 끄면 마커 제목을 비운다")
    func labelsOffClearsTitle() {
        let pins = [pin("a", lat: 37.5, lng: 127.0)]

        let on = PlaceMap.markers(pins: pins, roomColors: ["r1": .red], selectedPinID: nil, showsLabels: true)
        let off = PlaceMap.markers(pins: pins, roomColors: ["r1": .red], selectedPinID: nil, showsLabels: false)

        #expect(on.first?.title == "장소 a")
        #expect(off.first?.title == nil)
    }

    @Test("카메라 idle 이벤트에서 줌을 꺼낸다")
    func idleZoomFromEvent() {
        let position = MapCameraPosition(coordinate: MapCoordinate(latitude: 37.5, longitude: 127.0), zoom: 17)

        #expect(PlaceMap.idleZoom(in: .didIdleAt(position)) == 17)
        #expect(PlaceMap.idleZoom(in: .didTapMarker(id: "a")) == nil)
        #expect(PlaceMap.idleZoom(in: .didTap(MapCoordinate(latitude: 0, longitude: 0))) == nil)
    }

    @Test("색 없는 방은 마커 기본색을 쓴다 — 시안의 색 없는 핀과 같은 회색")
    func noColorUsesMarkerDefault() {
        #expect(PlaceMap.tint(for: nil) == MapMarkerStyle.defaultTint)
    }

    @Test("색 미선택(gray)은 색이 없는 방(nil)과 같은 기본색으로 떨어진다")
    func grayFallsBack() {
        #expect(PlaceMap.tint(for: .gray) == PlaceMap.tint(for: nil))
    }

    @Test("12색은 서로 다른 색으로 짝지어진다 — 한 색이 다른 색을 덮어쓰면 방 구분이 사라진다")
    func paletteIsDistinct() {
        // gray 는 "색 미선택" 이라 팔레트 밖이다(기본색으로 폴백).
        let picked = RoomColor.allCases.filter { $0 != .gray }
        let tints = Set(picked.map { PlaceMap.tint(for: $0) })
        #expect(tints.count == picked.count)
    }

    // MARK: - 탭

    @Test("마커 탭은 그 핀 id 를 올려 보낸다")
    func markerTapCarriesPinID() {
        #expect(PlaceMap.tappedPinID(in: .didTapMarker(id: "a")) == "a")
    }

    @Test("빈 곳 탭·카메라 이동은 장소를 열지 않는다 — 지도를 움직였다고 시트가 바뀌면 안 된다")
    func otherEventsDoNotSelect() {
        let coordinate = MapCoordinate(latitude: 37.5, longitude: 127.0)
        #expect(PlaceMap.tappedPinID(in: .didTap(coordinate)) == nil)
        #expect(PlaceMap.tappedPinID(in: .didIdleAt(MapCameraPosition(coordinate: coordinate, zoom: 15))) == nil)
    }

    // MARK: - 카메라

    @Test("핀이 없으면 기본 카메라를 유지한다")
    func defaultCameraWithoutPins() {
        #expect(PlaceMap.camera(for: []) == .position(PlaceMap.defaultCamera))
    }

    @Test("핀이 있으면 전부 보이도록 맞춘다")
    func fitCameraWithPins() {
        let pins = [pin("a", lat: 37.5, lng: 127.0), pin("b", lat: 37.6, lng: 127.1)]
        #expect(PlaceMap.camera(for: pins) == .fit(
            coordinates: [
                MapCoordinate(latitude: 37.5, longitude: 127.0),
                MapCoordinate(latitude: 37.6, longitude: 127.1),
            ],
            padding: PlaceMap.fitPadding
        ))
    }

    // MARK: - 현위치 (005-1)

    @Test("현위치가 서 있으면 핀 맞춤 대신 그 자리를 비춘다 — 방금 사용자가 낸 요청이다")
    func myLocationBeatsPinFit() {
        let pins = [pin("a", lat: 37.5, lng: 127.0), pin("b", lat: 37.6, lng: 127.1)]
        let me = Coordinate(latitude: 37.5443, longitude: 127.0557)

        #expect(PlaceMap.camera(for: pins, focusing: me) == .position(
            MapCameraPosition(
                coordinate: MapCoordinate(latitude: 37.5443, longitude: 127.0557),
                zoom: PlaceMap.myLocationZoom
            )
        ))
    }

    @Test("핀이 없어도 현위치로 간다 — 기본 카메라(강남)에 머물지 않는다")
    func myLocationWithoutPins() {
        let me = Coordinate(latitude: 37.5443, longitude: 127.0557)
        #expect(PlaceMap.camera(for: [], focusing: me) != .position(PlaceMap.defaultCamera))
    }

    @Test("현위치가 없으면 지금까지와 같다 — 핀에 맞춘다")
    func withoutMyLocationFallsBackToFit() {
        let pins = [pin("a", lat: 37.5, lng: 127.0)]
        #expect(PlaceMap.camera(for: pins, focusing: nil) == PlaceMap.camera(for: pins))
    }
}

@Suite("PlaceMapButtonMetrics — 지도 위 부유 버튼 줄의 자리(005-1 `2792:142415`)")
struct PlaceMapButtonMetricsTests {
    /// 시안 프레임 폭.
    private let designWidth: CGFloat = 375

    @Test("현위치 버튼은 시안 자리에 선다 — x 315..355")
    func myLocationHorizontalPlacement() {
        let right = designWidth - PlaceMapButtonMetrics.trailing
        #expect(right == 355)
        #expect(right - PlaceMapButtonMetrics.placeDetail.myLocationSize == 315)
    }

    @Test("'저장된 방' 은 현위치 왼쪽으로 물러난다 — 오른쪽 끝 307(시안), 화면 끝에서 68")
    func savedRoomsHorizontalPlacement() {
        let right = designWidth
            - PlaceMapButtonMetrics.trailing
            - PlaceMapButtonMetrics.placeDetail.myLocationSize
            - PlaceMapButtonMetrics.spacing

        #expect(right == 307)
        #expect(designWidth - right == 68)
    }

    @Test("버튼 줄은 시트 윗끝에서 18 띄운다 — 시안 시트 441, '저장된 방' 아래끝 423")
    func bottomGapFromSheetTop() {
        let designSheetTop: CGFloat = 441
        let designSavedRoomsBottom: CGFloat = 423
        #expect(PlaceMapButtonMetrics.placeDetail.bottomGap == designSheetTop - designSavedRoomsBottom)
    }

    // MARK: - 방 리스트·방 상세 (`004-1-1 방 상세 peek`, `2542:125409`)

    // 375×812 PNG 픽셀 실측: 흰 원판 y 549..584, 오른쪽 끝에서 21, 시트 윗끝(604)에서 20.
    // 장소 상세의 40 을 세 화면에 돌려 쓰던 것이 어긋남의 원인이었다.
    @Test("방 지도 버튼은 장소 상세보다 작고 더 띄운다 — 36×36 · 시트에서 20")
    func roomMapPresetMatchesDesign() {
        #expect(PlaceMapButtonMetrics.roomMap.myLocationSize == 36)
        #expect(PlaceMapButtonMetrics.roomMap.bottomGap == 20)
    }

    @Test("두 프리셋은 서로 다르다 — 한 벌을 세 화면에 돌려 쓰면 다시 어긋난다")
    func presetsDiffer() {
        #expect(PlaceMapButtonMetrics.roomMap != PlaceMapButtonMetrics.placeDetail)
    }

    @Test("아이콘 크기와 오른쪽 여백은 두 화면이 같다")
    func sharedValues() {
        #expect(PlaceMapButtonMetrics.myLocationIconSize == 20)
        #expect(PlaceMapButtonMetrics.trailing == 20)
    }
}

@Suite("PlaceMapCameraMode — 진입점마다 다른 카메라 규칙")
struct PlaceMapCameraModeTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func pin(_ id: String, lat: Double, lng: Double, room: String = "r1") -> Pin {
        PinFixture.pin(
            id: PinID(id),
            roomID: room,
            category: .worthVisiting,
            title: "장소 \(id)",
            address: "주소 \(id)",
            coordinate: Coordinate(latitude: lat, longitude: lng),
            createdAt: now
        )
    }

    @Test("centered 는 그 장소를 기본 줌으로 가운데 둔다 — 마커가 하나뿐이라 맞출 범위가 없다")
    func centeredUsesFixedZoom() {
        let place = Coordinate(latitude: 37.5, longitude: 127.0)

        #expect(PlaceMap.camera(.centered(place), pins: [], focusing: nil) == .position(
            MapCameraPosition(
                coordinate: MapCoordinate(latitude: 37.5, longitude: 127.0),
                zoom: PlaceMap.defaultCamera.zoom
            )
        ))
    }

    @Test("centered 여도 현위치가 서 있으면 그쪽을 비춘다 — 방금 사용자가 낸 요청이다")
    func myLocationBeatsCentered() {
        let place = Coordinate(latitude: 37.5, longitude: 127.0)
        let me = Coordinate(latitude: 37.5443, longitude: 127.0557)

        #expect(PlaceMap.camera(.centered(place), pins: [], focusing: me) == .position(
            MapCameraPosition(
                coordinate: MapCoordinate(latitude: 37.5443, longitude: 127.0557),
                zoom: PlaceMap.defaultCamera.zoom
            )
        ))
    }

    @Test("현위치로 옮겨도 축척이 흔들리지 않는다 — 진입 줌과 현위치 줌이 같은 값이다")
    func zoomIsStableAcrossFocus() {
        #expect(PlaceMap.myLocationZoom == PlaceMap.defaultCamera.zoom)
    }

    @Test("fitPins 는 기존 핀 맞춤과 완전히 같다 — 저장 탭의 규칙이 바뀌면 안 된다")
    func fitPinsMatchesLegacyRule() {
        let pins = [pin("a", lat: 37.5, lng: 127.0), pin("b", lat: 37.6, lng: 127.1)]
        let me = Coordinate(latitude: 37.5443, longitude: 127.0557)

        #expect(PlaceMap.camera(.fitPins, pins: pins, focusing: nil) == PlaceMap.camera(for: pins))
        #expect(PlaceMap.camera(.fitPins, pins: pins, focusing: me) == PlaceMap.camera(for: pins, focusing: me))
        #expect(PlaceMap.camera(.fitPins, pins: [], focusing: nil) == PlaceMap.camera(for: []))
    }
}
