import DesignSystem
import MapUI
import SwiftUI

struct ArchiveMapLayer: View {
    private static let defaultCamera = MapCameraPosition(
        coordinate: MapCoordinate(latitude: 37.4966, longitude: 127.0530),
        zoom: 15
    )

    /// 지도 위에 겹친 바텀시트가 화면 하단에서 가리는 높이(safe-area 제외분).
    /// 구글 로고·저작권 표시가 이 위로 밀려 올라가 가려지지 않는다 — Google Maps Platform
    /// 약관이 attribution 가림을 금지하고, 공식 문서가 하단 커스텀 UI 에 padding 을 권고한다.
    let bottomInset: CGFloat

    var body: some View {
        ZStack {
            Color.mhBackgroundNormalAlternative
            #if canImport(GoogleMaps)
            if MapService.isConfigured {
                MapView(
                    camera: Self.defaultCamera,
                    markers: [],
                    padding: EdgeInsets(top: 0, leading: 0, bottom: bottomInset, trailing: 0),
                    onEvent: { _ in }
                )
            }
            #endif
        }
        .ignoresSafeArea()
    }
}
