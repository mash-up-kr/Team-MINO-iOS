import DesignSystem
import SwiftUI

/// Figma `Button/Icon/Normal` — 테두리·배경 없이 아이콘만.
struct RoomDetailPlainIconButton: View {
    let icon: MHIcon
    var size: CGFloat = 24
    var tint: Color = .mhLabelAlternative
    /// 탭 영역 한 변. 이웃 버튼과 붙어 있으면 겹치지 않게 줄인다.
    var hitSize: CGFloat = 44
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .frame(width: size, height: size)
                .foregroundStyle(tint)
                .frame(width: hitSize, height: hitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
