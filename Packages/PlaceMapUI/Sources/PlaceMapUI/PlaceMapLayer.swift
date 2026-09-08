import DesignSystem
import Domain
import MapUI
import SwiftUI

public struct PlaceMapLayer: View {
    /// 지도 위에 겹친 바텀시트가 화면 하단에서 가리는 높이(safe-area 제외분).
    /// 구글 로고·저작권 표시가 이 위로 밀려 올라가 가려지지 않는다 — Google Maps Platform
    /// 약관이 attribution 가림을 금지하고, 공식 문서가 하단 커스텀 UI 에 padding 을 권고한다.
    let bottomInset: CGFloat

    /// 지금 보고 있는 방의 핀. 방을 열지 않았으면 비어 있고, 그때는 기본 카메라를 유지한다.
    let pins: [Pin]

    /// 현위치 버튼(005-1)이 잡아 둔 내 위치. 서 있으면 핀 맞춤 대신 여기를 비춘다.
    let myLocation: Coordinate?

    /// 방 id → 대표 색. 마커 색이 **소속 방의 색**을 따른다(005-1 ① · PRD [SYS-004]).
    /// 방 리스트 탭은 여러 방의 핀이 한 지도에 뜨므로 방 하나가 아니라 표를 받는다.
    /// 색을 안 고른 방(`nil`·`gray`)이나 표에 없는 방은 기본색으로 떨어진다.
    let roomColors: [String: RoomColor]

    /// 지금 장소 상세로 열려 있는 핀. 그 마커만 선택 상태로 그린다(005-1 ①).
    /// 선택 상태는 지도가 들지 않는다 — 어느 장소를 보고 있는지는 이미 화면이 아는 값이라
    /// 지도가 따로 들면 시트와 어긋날 수 있다.
    let selectedPinID: String?

    /// 마커를 눌렀다(핀 id). 화면 전환은 Store 의 Nav 로 흘러야 하므로 여기서는 Coordinator 를
    /// 부르지 않고 action 만 올려 보낸다 — 받는 쪽이 `RoomDetailAction.tapLocation` 으로 잇는다.
    let onSelectPin: (String) -> Void

    /// 카메라를 어떻게 잡을지. 기본은 핀 맞춤이라 지금까지 쓰던 진입점은 넘기지 않아도 된다.
    let cameraMode: PlaceMapCameraMode

    /// 지금 카메라 줌. 라벨을 그릴지 판단한다(``PlaceMap/showsLabels(atZoom:)``).
    /// `nil` 이면 아직 카메라 idle 을 못 받은 상태다.
    let zoom: Float?

    /// 카메라 이동이 멈췄다(줌). 라벨·클러스터 판정에 쓰라고 올려 보낸다 — 지도가 스스로
    /// 들지 않는 것은 선택 상태와 같은 이유다(화면이 아는 값과 어긋날 수 있다).
    let onCameraIdle: ((Float) -> Void)?

    /// 클러스터를 눌렀다(그 클러스터의 좌표) — 그 자리를 한 단계 확대해 묶음이 풀리게 한다.
    let onZoomIn: ((MapCoordinate) -> Void)?

    public init(
        bottomInset: CGFloat,
        pins: [Pin],
        myLocation: Coordinate?,
        roomColors: [String: RoomColor],
        selectedPinID: String?,
        onSelectPin: @escaping (String) -> Void,
        cameraMode: PlaceMapCameraMode = .fitPins,
        zoom: Float? = nil,
        onCameraIdle: ((Float) -> Void)? = nil,
        onZoomIn: ((MapCoordinate) -> Void)? = nil
    ) {
        self.bottomInset = bottomInset
        self.pins = pins
        self.myLocation = myLocation
        self.roomColors = roomColors
        self.selectedPinID = selectedPinID
        self.onSelectPin = onSelectPin
        self.cameraMode = cameraMode
        self.zoom = zoom
        self.onCameraIdle = onCameraIdle
        self.onZoomIn = onZoomIn
    }

    /// 지금 그릴 마커. 탭 조회(어느 클러스터를 눌렀는지)에도 같은 값을 써야 해서 한 번만 만든다.
    private var currentMarkers: [MapMarker] {
        PlaceMap.clustered(
            pins: pins,
            zoom: zoom,
            roomColors: roomColors,
            selectedPinID: selectedPinID,
            showsLabels: PlaceMap.showsLabels(atZoom: zoom)
        )
    }

    public var body: some View {
        ZStack {
            Color.mhBackgroundNormalAlternative
            #if canImport(GoogleMaps)
            if MapService.isConfigured {
                let markers = currentMarkers
                MapView(
                    camera: PlaceMap.camera(cameraMode, pins: pins, focusing: myLocation),
                    markers: markers,
                    padding: EdgeInsets(top: 0, leading: 0, bottom: bottomInset, trailing: 0),
                    onEvent: { event in
                        if let id = PlaceMap.tappedPinID(in: event) {
                            // 클러스터 탭은 장소를 지목하지 않는다 — 어느 장소인지 정해지지 않아
                            // 상세를 열 수 없다. **확대로 응한다**(PRD 에 이 동작 지정이 없어 플래그).
                            if PlaceMap.isClusterID(id) {
                                markers.first { $0.id == id }.map { onZoomIn?($0.coordinate) }
                            } else {
                                onSelectPin(id)
                            }
                        }
                        if let zoom = PlaceMap.idleZoom(in: event) { onCameraIdle?(zoom) }
                    }
                )
            }
            #endif
        }
        .ignoresSafeArea()
    }
}

/// 지도 카메라를 무엇에 맞출지. 화면마다 규칙이 달라 진입점이 고른다.
public enum PlaceMapCameraMode: Equatable, Sendable {
    /// 핀을 전부 담도록 맞춘다(저장 탭). 지금까지의 유일한 규칙이라 기본값이다.
    case fitPins

    /// 한 장소를 고정 줌으로 가운데 둔다(홈 카드덱에서 연 장소 상세).
    /// 마커가 하나뿐이라 맞출 범위가 없어 `fitPins` 로는 줌이 정해지지 않는다.
    case centered(Coordinate)

    /// 한 지점을 **지정한 줌**으로 가운데 둔다. 클러스터를 눌러 확대할 때 쓴다 —
    /// `centered` 는 기본 줌으로 고정이라 "지금보다 더 확대" 를 표현할 수 없다.
    case zoomed(MapCoordinate, zoom: Float)
}

/// 지도에 **무엇을** 그릴지 정하는 순수 계산부. 뷰에서 떼어 둔 이유는 두 가지다:
/// 지도를 띄우지 않고 검증할 수 있고, `View` 가 `@MainActor` 라 그 안에 두면 계산 하나 부르는
/// 데도 메인 액터가 필요해진다(Swift 6 에서 테스트가 런타임 격리 검사에 걸린다).
///
/// `MapUI` 의 `MarkerDiff` 와 같은 결의 분리다 — SDK 조작과 판단을 갈라 둔다.
public enum PlaceMap {
    /// 볼 핀이 없을 때의 카메라(강남 일대). 방을 열지 않았거나 방에 저장된 장소가 없는 상태다.
    public static let defaultCamera = MapCameraPosition(
        coordinate: MapCoordinate(latitude: 37.4966, longitude: 127.0530),
        zoom: 15
    )

    /// 핀이 화면 가장자리에 붙지 않도록 카메라를 맞출 때 두는 여백(pt).
    public static let fitPadding: Double = 60

    /// 핀 아래 장소명을 그리기 시작하는 줌.
    ///
    /// 더 멀리서는 핀이 촘촘해 이름끼리 겹쳐 읽히지 않고, 화면에 뜨는 마커가 많아 이름마다
    /// 그림을 합성하는 비용도 커진다. 기본 카메라 줌(``defaultCamera``)이 이 값이라 진입
    /// 상태에서는 라벨이 보인다.
    ///
    /// 시안에 임계값 지정이 없어(플래그) 기본 줌을 경계로 삼았다.
    public static let labelZoomThreshold: Float = 15

    /// 이 줌에서 라벨을 그리는가. 줌을 아직 모르면(카메라 idle 전) 기본 카메라 줌으로 판단한다.
    public static func showsLabels(atZoom zoom: Float?) -> Bool {
        (zoom ?? defaultCamera.zoom) >= labelZoomThreshold
    }

    /// 현위치로 옮겨 갈 때의 줌.
    ///
    /// 시안(005-1)에 지정이 없다. 새 숫자를 지어내지 않고 이 화면이 이미 쓰는 기본 줌을 그대로
    /// 쓴다 — 지금 줌을 유지하려면 카메라 idle 을 계속 추적해 들고 있어야 하는데, 버튼 하나에
    /// 그 상태를 들일 이유가 없다.
    public static var myLocationZoom: Float { defaultCamera.zoom }

    /// 핀을 지도 마커로 옮긴다. 마커 `id` 는 핀 id — 탭 이벤트가 이 값으로 되돌아온다.
    /// 지금 열려 있는 핀만 선택 상태가 된다(005-1 ①).
    ///
    /// **색은 마커마다 다르다** — PRD [SYS-004] 가 "[SCR-004] 방 리스트 탭: 내 모든 방의 장소
    /// 마커를 한 지도에 표시하며, **각 마커는 소속 방의 대표 색상을 따른다**" 로 못박았다.
    /// 방 상세는 방이 하나라 결과적으로 다 같은 색이 된다 — 같은 함수로 두 화면을 덮는다.
    ///
    /// - Parameter roomColors: 방 id → 대표 색. 색을 안 고른 방(`nil`)이나 목록에 없는 방 id 는
    ///   기본 회색으로 떨어진다(``tint(for:)``) — 방 목록보다 핀이 먼저 도착해도 마커가 사라지지
    ///   않고 회색으로 선다.
    /// - Parameter showsLabels: 핀 아래 장소명을 그릴지. **꺼지면 `title` 을 비워** 보낸다 —
    ///   라벨을 그릴지 말지는 여기서 정하고 `MapView` 는 받은 값을 그리기만 한다.
    public static func markers(
        pins: [Pin],
        roomColors: [String: RoomColor],
        selectedPinID: String?,
        showsLabels: Bool = true
    ) -> [MapMarker] {
        pins.map { pin in
            MapMarker(
                id: pin.id.value,
                coordinate: MapCoordinate(
                    latitude: pin.place.coordinate.latitude,
                    longitude: pin.place.coordinate.longitude
                ),
                title: showsLabels ? pin.place.name : nil,
                style: MapMarkerStyle(
                    tint: tint(for: roomColors[pin.roomID]),
                    isSelected: pin.id.value == selectedPinID
                )
            )
        }
    }

    /// 핀이 있으면 전부 보이도록 맞추고(004-1 ④), 없으면 기본 카메라를 유지한다.
    ///
    /// `myLocation` 이 서 있으면 그쪽이 이긴다 — 현위치 버튼(005-1)을 누른 결과라 방금 사용자가
    /// 낸 요청이 핀 맞춤보다 뒤에 온 판단이다. 방이 바뀌면 그 요청은 사라져(``ArchiveCoordinator``의
    /// `mapFocus`) 다시 핀에 맞춰진다.
    public static func camera(for pins: [Pin], focusing myLocation: Coordinate? = nil) -> MapCamera {
        if let myLocation {
            return .position(
                MapCameraPosition(
                    coordinate: MapCoordinate(
                        latitude: myLocation.latitude,
                        longitude: myLocation.longitude
                    ),
                    zoom: myLocationZoom
                )
            )
        }
        guard !pins.isEmpty else { return .position(defaultCamera) }
        return .fit(
            coordinates: pins.map {
                MapCoordinate(
                    latitude: $0.place.coordinate.latitude,
                    longitude: $0.place.coordinate.longitude
                )
            },
            padding: fitPadding
        )
    }

    /// 모드에 따라 카메라를 고른다. `fitPins` 는 기존 규칙(``camera(for:focusing:)``)을 그대로 쓴다.
    ///
    /// 현위치 요청(`myLocation`)은 두 모드 모두에서 이긴다 — 방금 사용자가 낸 요청이라
    /// 진입 규칙보다 뒤에 온 판단이다.
    public static func camera(
        _ mode: PlaceMapCameraMode,
        pins: [Pin],
        focusing myLocation: Coordinate?
    ) -> MapCamera {
        switch mode {
        case .fitPins:
            return camera(for: pins, focusing: myLocation)
        case .centered(let place):
            let target = myLocation ?? place
            return .position(
                MapCameraPosition(
                    coordinate: MapCoordinate(latitude: target.latitude, longitude: target.longitude),
                    // 현위치 줌과 같은 값이라(둘 다 기본 줌) 현위치로 옮겨도 축척이 흔들리지 않는다.
                    zoom: defaultCamera.zoom
                )
            )
        case .zoomed(let coordinate, let zoom):
            // 현위치 요청보다 뒤에 온 조작이라 이쪽이 이긴다 — 사용자가 방금 누른 클러스터다.
            return .position(MapCameraPosition(coordinate: coordinate, zoom: zoom))
        }
    }

    /// 지도 이벤트에서 "눌린 핀"만 골라낸다. 빈 곳 탭·카메라 이동은 이 화면이 쓰지 않는다 —
    /// 지도를 움직였다고 시트가 바뀌면 안 되기 때문이다.
    public static func tappedPinID(in event: MapEvent) -> String? {
        switch event {
        case .didTapMarker(let id): id
        case .didTap, .didIdleAt: nil
        }
    }

    /// 카메라가 멈춘 시점의 줌. 라벨을 그릴 줌인지 판단하는 데 쓴다.
    public static func idleZoom(in event: MapEvent) -> Float? {
        switch event {
        case .didIdleAt(let position): position.zoom
        case .didTapMarker, .didTap: nil
        }
    }

    /// 방 색 → 마커 색.
    ///
    /// `RoomColorPalette.entries` 의 **채움색**과 같은 짝이다 — 사용자가 피커에서 고른 칸의
    /// 색이 곧 "방 색"이라 마커도 그 색을 쓴다. 그 배열의 `fill` 이 `RoomCreationUI` 안에서
    /// internal 이라 밖에서 읽을 수 없어 여기서 다시 짝짓는다. **팔레트를 고치면 양쪽을 함께
    /// 고쳐야 한다** — `RoomColorPalette` 에 공개 접근자가 생기면 이 switch 는 지운다.
    ///
    /// 두 enum 의 rawValue 에 기대지 않고 명시적으로 짝짓는 것도 그쪽과 같은 이유다:
    /// 이름으로 이으면 한쪽이 바뀌어도 컴파일이 통과하고 런타임에 색만 사라진다.
    public static func tint(for color: RoomColor?) -> Color {
        switch color {
        case .red: .mhRed60
        case .redOrange: .mhRedOrange70
        case .orange: .mhOrange70
        case .lime: .mhLime80
        case .green: .mhGreen90
        case .cyan: .mhCyan90
        case .lightBlue: .mhLightBlue60
        case .blue: .mhBlue65
        case .violet: .mhViolet80
        case .pink: .mhPink90
        case .purple: .mhPurple70
        case .brown: .mhBrown70
        // 색 미선택(`gray`)과 팔레트 밖 값(`nil`)은 그릴 방 색이 없어 마커 기본색으로 떨어진다.
        // 시안의 색 없는 핀이 쓰는 회색이라 DesignSystem 토큰이 아니라 마커 쪽 값을 받아 쓴다.
        case .gray, .none: MapMarkerStyle.defaultTint
        }
    }
}
