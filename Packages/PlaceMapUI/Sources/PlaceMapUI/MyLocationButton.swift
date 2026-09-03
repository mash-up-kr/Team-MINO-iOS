import DesignSystem
import SwiftUI

/// 지도 우하단 현위치 버튼. Figma `005-1 half`(`2792:142415`) 안의 `3276:209987`.
///
/// ## 왜 GoogleMaps 기본 버튼(`settings.myLocationButton`)이 아닌가
/// SDK 에도 같은 일을 하는 버튼이 있지만 **모양도 자리도 우리가 못 정한다.**
///
/// - `GMSUISettings.myLocationButton` 은 `BOOL` 하나뿐이다. 헤더 전체에 프레임·크기·radius·
///   그림자를 정하는 API 가 없어, 시안의 40×40 / radius 999 / 2단 `Shadow/Normal/Medium` 을
///   맞출 수단이 없다.
/// - 자리도 `GMSMapView.padding` 으로 간접적으로만 밀린다("safe area insets position map
///   controls such as the compass, my location button and floor picker"). 그 padding 은 이미
///   attribution 을 시트 위로 올리는 데 쓰고 있어(``PlaceMapLayer/bottomInset``) 버튼 자리를
///   맞추자고 건드릴 수 없고, 건드리면 Google Maps Platform 약관(attribution 가림 금지)이 깨진다.
///   `저장된 방` 과 8pt 간격으로 나란히 세우는 것도 좌표계가 달라 보장할 수 없다.
/// - 아이콘도 다르다. 시안은 **고리 + 안쪽 4눈금, 가운데 점 없음**이고, SDK 가 쓰는 Material
///   `my_location` 은 바깥으로 뻗는 눈금 + 가운데 점이다(시안 렌더 픽셀 확인).
/// - `myLocationEnabled` 를 켜야 따라오는 파란 점·정확도 원이 시안에 없다. 게다가 SDK 가 자기
///   CoreLocation 스택으로 권한을 따로 물어 ``CurrentLocationUseCase``·`PermissionRepository`
///   를 우회한다 — 거리순 정렬(004-1 ⑥)과 권한 상태가 갈릴 수 있다.
///
/// ## 왜 ``MHIconButton`` 이 아닌가
/// 크기(40×40 원형)·아이콘(20×20)·아이콘 색(`Label/Normal`)까지 DS 의 `Button/Icon/Outlined` 와
/// 같지만, 시안의 이 버튼은 그 컴포넌트의 인스턴스가 **아니라** 손으로 짠 프레임이다 —
/// 테두리가 없고 대신 흰 면 + `Shadow/Normal/Medium` 으로 지도에서 떠 있다. `MHIconButton` 은
/// 테두리(`Line/Normal/Neutral` 1px)를 항상 그리고 그걸 끄는 API 가 없어, 그대로 쓰면 시안에
/// 없는 실선이 생긴다. `저장된 방`(``SavedRoomsButton``)이 `MHButton` 위에 같은 흰 면·그림자를
/// 덧대는 것과 같은 결의 처리다.
///
/// 그 대가로 DS 의 press 오버레이가 없다(`MHButtonStyle.pressedOpacity` 는 DesignSystem 내부).
/// 시안의 이 프레임에도 interaction 레이어가 없어 눌림 상태가 정의돼 있지 않다 —
/// 정해지면 그때 DS 에 테두리 없는 variant 를 추가하고 이 뷰를 걷어낸다.
public struct MyLocationButton: View {
    let action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(.myLocation)
                .resizable()
                .frame(
                    width: PlaceMapButtonMetrics.myLocationIconSize,
                    height: PlaceMapButtonMetrics.myLocationIconSize
                )
                .foregroundStyle(.mhLabelNormal)
                // 아이콘이 아니라 버튼 전체가 탭 영역이 되도록 프레임을 라벨에 건다.
                .frame(
                    width: PlaceMapButtonMetrics.myLocationSize,
                    height: PlaceMapButtonMetrics.myLocationSize
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)   // 기본 스타일의 강조색 틴트를 끈다 — 아이콘 색은 Label/Normal 이다
        .mapFloatingSurface(cornerRadius: PlaceMapButtonMetrics.myLocationSize / 2)
        .accessibilityLabel("현위치")
        // 방 리스트(003-1 ⑦)와 장소 상세(005-1)가 같은 버튼을 쓴다 — 화면 이름을 붙이지 않는다.
        .accessibilityIdentifier("Archive.myLocation")
    }
}

#Preview("현위치 버튼") {
    MyLocationButton {}
        .padding(40)
        .background(.mhBackgroundNormalAlternative)
}
