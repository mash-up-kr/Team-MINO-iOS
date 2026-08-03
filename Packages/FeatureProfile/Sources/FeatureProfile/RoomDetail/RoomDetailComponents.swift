import DesignSystem
import SwiftUI

/// Figma `Button/Icon/Outlined` — 40pt 정원 + 1px 테두리. `MHButton(icon:)` 은 정사각이라 대체 불가.
struct RoomDetailCircleIconButton: View {
    let icon: MHIcon
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundStyle(.mhLabelNormal)
                .frame(width: 40, height: 40)
                .overlay { Circle().strokeBorder(.mhLineNormalNeutral, lineWidth: 1) }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

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

/// 카드 썸네일. 이미지가 붙으면 `MHThumbnail(Image(...), ...)` 로 교체한다.
struct RoomDetailThumbnail: View {
    var ratio: MHThumbnailRatio = .square

    var body: some View {
        MHThumbnail(Image(.blank), ratio: ratio, radius: true, border: true) {
            ZStack {
                // Fill/* 토큰이 반투명이라 불투명 배경 위에 얹어야 아래 이미지가 비치지 않는다
                Color.mhBackgroundNormalNormal
                Color.mhFillAlternative
                Image(.image)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .foregroundStyle(.mhLineNormalNeutral)
            }
        }
    }
}

/// `아이콘 + 수치` 메타 표기.
struct RoomDetailMetric: View {
    let icon: MHIcon
    let text: String
    var iconSize: CGFloat = 18
    var typography: MHTypography = .label2Medium

    var body: some View {
        HStack(spacing: 2) {
            Image(icon)
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(.mhLabelAlternative)
            Text(text)
                .mhTypography(typography)
                .foregroundStyle(.mhLabelAlternative)
        }
    }
}
