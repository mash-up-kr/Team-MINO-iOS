import DesignSystem
import MapUI
import SwiftUI

struct ArchiveMapLayer: View {
    private static let defaultCamera = MapCameraPosition(
        coordinate: MapCoordinate(latitude: 37.4966, longitude: 127.0530),
        zoom: 15
    )

    var body: some View {
        ZStack {
            Color.mhBackgroundNormalAlternative
            #if canImport(GoogleMaps)
            if MapService.isConfigured {
                MapView(camera: Self.defaultCamera, markers: [], onEvent: { _ in })
            }
            #endif
        }
        .ignoresSafeArea()
    }
}
