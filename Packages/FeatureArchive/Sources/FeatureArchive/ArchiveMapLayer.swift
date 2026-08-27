import DesignSystem
import Domain
import MapUI
import SwiftUI

struct ArchiveMapLayer: View {
    /// 지도 위에 겹친 바텀시트가 화면 하단에서 가리는 높이(safe-area 제외분).
    /// 구글 로고·저작권 표시가 이 위로 밀려 올라가 가려지지 않는다 — Google Maps Platform
    /// 약관이 attribution 가림을 금지하고, 공식 문서가 하단 커스텀 UI 에 padding 을 권고한다.
    let bottomInset: CGFloat

    /// 지금 보고 있는 방의 핀. 방을 열지 않았으면 비어 있고, 그때는 기본 카메라를 유지한다.
    let pins: [Pin]

    /// 방 대표 색 — 마커 색이 방 색을 따른다(005-1 ①). 색을 안 고른 방(`nil`·`gray`)은 기본색.
    let roomColor: RoomColor?

    /// 지금 장소 상세로 열려 있는 핀. 그 마커만 선택 상태로 그린다(005-1 ①).
    /// 선택 상태는 지도가 들지 않는다 — 어느 장소를 보고 있는지는 이미 화면이 아는 값이라
    /// 지도가 따로 들면 시트와 어긋날 수 있다.
    let selectedPinID: String?

    /// 마커를 눌렀다(핀 id). 화면 전환은 Store 의 Nav 로 흘러야 하므로 여기서는 Coordinator 를
    /// 부르지 않고 action 만 올려 보낸다 — 받는 쪽이 `RoomDetailAction.tapLocation` 으로 잇는다.
    let onSelectPin: (String) -> Void

    var body: some View {
        ZStack {
            Color.mhBackgroundNormalAlternative
            #if canImport(GoogleMaps)
            if MapService.isConfigured {
                MapView(
                    camera: ArchiveMap.camera(for: pins),
                    markers: ArchiveMap.markers(pins: pins, roomColor: roomColor, selectedPinID: selectedPinID),
                    padding: EdgeInsets(top: 0, leading: 0, bottom: bottomInset, trailing: 0),
                    onEvent: { event in
                        if let id = ArchiveMap.tappedPinID(in: event) { onSelectPin(id) }
                    }
                )
            }
            #endif
        }
        .ignoresSafeArea()
    }
}

/// 지도에 **무엇을** 그릴지 정하는 순수 계산부. 뷰에서 떼어 둔 이유는 두 가지다:
/// 지도를 띄우지 않고 검증할 수 있고, `View` 가 `@MainActor` 라 그 안에 두면 계산 하나 부르는
/// 데도 메인 액터가 필요해진다(Swift 6 에서 테스트가 런타임 격리 검사에 걸린다).
///
/// `MapUI` 의 `MarkerDiff` 와 같은 결의 분리다 — SDK 조작과 판단을 갈라 둔다.
enum ArchiveMap {
    /// 볼 핀이 없을 때의 카메라(강남 일대). 방을 열지 않았거나 방에 저장된 장소가 없는 상태다.
    static let defaultCamera = MapCameraPosition(
        coordinate: MapCoordinate(latitude: 37.4966, longitude: 127.0530),
        zoom: 15
    )

    /// 핀이 화면 가장자리에 붙지 않도록 카메라를 맞출 때 두는 여백(pt).
    static let fitPadding: Double = 60

    /// 방의 핀을 지도 마커로 옮긴다. 마커 `id` 는 핀 id — 탭 이벤트가 이 값으로 되돌아온다.
    /// 색은 방 하나에 하나라 전부 같고, 지금 열려 있는 핀만 선택 상태가 된다(005-1 ①).
    static func markers(pins: [Pin], roomColor: RoomColor?, selectedPinID: String?) -> [MapMarker] {
        let roomTint = tint(for: roomColor)
        return pins.map { pin in
            MapMarker(
                id: pin.id.value,
                coordinate: MapCoordinate(
                    latitude: pin.place.coordinate.latitude,
                    longitude: pin.place.coordinate.longitude
                ),
                title: pin.place.name,
                style: MapMarkerStyle(tint: roomTint, isSelected: pin.id.value == selectedPinID)
            )
        }
    }

    /// 핀이 있으면 전부 보이도록 맞추고(004-1 ④), 없으면 기본 카메라를 유지한다.
    static func camera(for pins: [Pin]) -> MapCamera {
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

    /// 지도 이벤트에서 "눌린 핀"만 골라낸다. 빈 곳 탭·카메라 이동은 이 화면이 쓰지 않는다 —
    /// 지도를 움직였다고 시트가 바뀌면 안 되기 때문이다.
    static func tappedPinID(in event: MapEvent) -> String? {
        switch event {
        case .didTapMarker(let id): id
        case .didTap, .didIdleAt: nil
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
    static func tint(for color: RoomColor?) -> Color {
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
        // 색 미선택(`gray`)과 팔레트 밖 값(`nil`)은 그릴 방 색이 없어 앱 기본색으로 떨어진다.
        case .gray, .none: .mhPrimaryNormal
        }
    }
}
