import DesignSystem
import SwiftUI

extension View {
    /// 지도 위에 떠 있는 버튼의 공통 표면 — 불투명 흰 면 + `Shadow/Normal/Medium`.
    ///
    /// 지도가 그대로 비치면 글자·아이콘이 안 읽히고 버튼의 경계도 사라진다. 시안(005-1 half)의
    /// 두 부유 버튼(``SavedRoomsButton``·``MyLocationButton``)이 모양만 다를 뿐 같은 처리를
    /// 쓰고 있어 여기 모았다 — 한쪽만 고쳐 둘이 갈라지지 않게 한다.
    ///
    /// - Parameter cornerRadius: 표면과 그림자를 함께 자를 반지름. 원형이면 한 변의 절반.
    public func mapFloatingSurface(cornerRadius: CGFloat) -> some View {
        background(.mhBackgroundNormalNormal, in: RoundedRectangle(cornerRadius: cornerRadius))
            .mhShadow(.medium, cornerRadius: cornerRadius)
    }
}
