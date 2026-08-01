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

/// Figma `Avatar/Avatar`. 사진 에셋이 없어 person 아이콘 플레이스홀더로 그린다.
struct RoomDetailAvatar: View {
    var size: CGFloat = 32
    var hasOuterStroke: Bool = true

    var body: some View {
        Circle()
            // 컨테이너는 Static/White, 그 위 사진 레이어를 회색 자리로 대체한다(시안 렌더와 동일)
            .fill(.mhStaticWhite)
            .overlay { Circle().fill(.mhFillStrong) }
            .overlay {
                Image(.personFill)
                    .resizable()
                    .frame(width: size * 0.5, height: size * 0.5)
                    .foregroundStyle(.mhStaticWhite)
            }
            .overlay { Circle().strokeBorder(.mhLineNormalAlternative, lineWidth: 1) }
            .frame(width: size, height: size)
            .overlay {
                if hasOuterStroke {
                    Circle().strokeBorder(.mhBackgroundNormalNormal, lineWidth: 1.5)
                }
            }
    }
}

/// Figma `Avatar/Avatar Group` — 6pt 씩 겹쳐 나열.
struct RoomDetailAvatarGroup: View {
    let count: Int
    var size: CGFloat = 24

    var body: some View {
        HStack(spacing: -6) {
            ForEach(0..<max(count, 1), id: \.self) { _ in
                RoomDetailAvatar(size: size)
            }
        }
    }
}

/// 헤더 좌측 pill — 아바타 그룹 + 검정 `+` 버튼.
struct RoomDetailMemberPill: View {
    let memberCount: Int
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: -6) {
            RoomDetailAvatarGroup(count: memberCount, size: 32)
            Button(action: onAdd) {
                Image(.plus)
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.mhInverseLabel)
                    .padding(7)
                    .background(Circle().fill(.mhPrimaryNormal))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("멤버 초대")
        }
        .padding(4)
        .background(Capsule().fill(.mhFillNormal))
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
