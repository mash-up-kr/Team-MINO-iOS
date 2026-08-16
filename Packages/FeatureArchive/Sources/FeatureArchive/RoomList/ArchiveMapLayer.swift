import DesignSystem
import MapUI
import SwiftUI

/// 저장 탭 배경 지도. Figma `003-1-1 peek`(node 1604:100087)의 전체화면 지도 레이어.
///
/// 시트·필터바 뒤에 깔리는 배경이라 상호작용 상태를 들지 않는다 — 카메라는 고정 상수이고
/// 마커는 비어 있다(`Domain.Pin` 에 좌표 필드가 없어 표시할 좌표가 아직 없다).
///
/// **키 미설정 시 placeholder 로 대체한다.** `GMSMapView` 는 `GMSServices.provideAPIKey` 없이
/// 생성하면 SDK 가 예외를 던져 크래시하므로(``MapService`` 주석), `isConfigured` 를 반드시 가드한다.
/// macOS 테스트 호스트에는 GoogleMaps 가 링크되지 않아(`canImport` 실패) 같은 자리로 폴백한다.
struct ArchiveMapLayer: View {
    /// 디자인 배경과 같은 강남·한티 일대. 좌표 기반 데이터가 붙으면 store 상태로 옮긴다.
    private static let defaultCamera = MapCameraPosition(
        coordinate: MapCoordinate(latitude: 37.4966, longitude: 127.0530),
        zoom: 15
    )

    var body: some View {
        map
            .ignoresSafeArea()
            .accessibilityIdentifier("RoomList.map")
    }

    @ViewBuilder
    private var map: some View {
        #if canImport(GoogleMaps)
        if MapService.isConfigured {
            MapView(camera: Self.defaultCamera, markers: [], onEvent: { _ in })
        } else {
            placeholder
        }
        #else
        placeholder
        #endif
    }

    /// 키 미설정·미링크 상태의 대체 배경. 지도가 없을 뿐 시트·필터바 레이아웃은 그대로 검증할 수 있다.
    private var placeholder: some View {
        ZStack {
            Color.mhBackgroundNormalAlternative
            Text("지도를 표시하려면 GoogleMaps API 키가 필요합니다\n(App/Config/Secrets.xcconfig)")
                .mhTypography(.label1NormalRegular)
                .foregroundStyle(.mhLabelAlternative)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Preview

#Preview("ArchiveMapLayer") {
    ArchiveMapLayer()
}
