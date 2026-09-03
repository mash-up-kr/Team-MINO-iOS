import DesignSystem
import PlaceMapUI
import SwiftUI

/// 지도 위에 떠 있는 '저장된 방' 버튼. Figma `005-1 half`(`4170:129600`).
///
/// 시안은 `Button/Button` outlined·medium(px20·py9·radius 10·Body 2/Normal - Medium) 그대로인데
/// **배경만 흰색**이고 그림자(`Shadow/Normal/Medium`)가 붙어 있다 — 지도 위에 떠 있어 배경이
/// 비치면 글자가 안 읽히기 때문이다. ``MHButton`` 의 outlined 는 배경이 투명하므로 흰 면과
/// 그림자를 ``SwiftUI/View/mapFloatingSurface(cornerRadius:)`` 로 덧댄다(현위치 버튼과 공유).
///
/// 비활성(중복 저장이 아닌 장소)은 시안에 없다 — 흰 면은 그대로 두고 ``MHButton`` 의 비활성
/// 토큰(Label/Disable)에 맡긴다.
struct SavedRoomsButton: View {
    /// `MHButton` medium 의 radius. 흰 면·그림자를 버튼과 같은 모양으로 잘라야 하는데
    /// `MHButton` 이 이 값을 밖으로 열어 두지 않아 여기서도 적는다.
    /// **`MHButtonSize.medium` 의 cornerRadius 가 바뀌면 함께 고쳐야 한다.**
    private static let cornerRadius: CGFloat = 10

    let action: () -> Void

    var body: some View {
        MHButton(
            "저장된 방",
            variant: .outlined,
            color: .assistive,
            size: .medium,
            leadingIcon: .folder,
            action: action
        )
        .mapFloatingSurface(cornerRadius: Self.cornerRadius)
        .accessibilityIdentifier("PlaceDetail.savedRooms")
    }
}

#Preview("저장된 방 버튼") {
    VStack(spacing: 20) {
        SavedRoomsButton {}
        SavedRoomsButton {}.disabled(true)
    }
    .padding(40)
    .background(.mhBackgroundNormalAlternative)
}
