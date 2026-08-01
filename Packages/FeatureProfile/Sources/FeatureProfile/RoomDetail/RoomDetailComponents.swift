import DesignSystem
import SwiftUI

// MARK: - 원형 아이콘 버튼

/// Figma `Button/Icon/Outlined` — 40pt 정원에 1px 테두리, 아이콘 20pt.
/// DesignSystem 의 `MHButton(icon:)` 은 정사각 rounded-rect 라 이 원형 모양을 만들 수 없어
/// 이 화면 안에서만 쓰는 로컬 뷰로 둔다(범용 수요가 확인되면 DS 로 승격).
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
                .overlay {
                    Circle().strokeBorder(.mhLineNormalNeutral, lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - 테두리 없는 아이콘 버튼

/// Figma `Button/Icon/Normal` — 테두리·배경 없이 아이콘만. 툴바·카드 더보기에 쓴다.
/// 아이콘이 24pt 미만이어도 탭 영역은 최소 44pt 를 확보한다.
struct RoomDetailPlainIconButton: View {
    let icon: MHIcon
    var size: CGFloat = 24
    var tint: Color = .mhLabelAlternative
    /// 탭 영역 한 변. 기본 44(HIG 최소). 버튼이 이웃과 붙어 있으면 겹치지 않게 줄인다.
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

// MARK: - 아바타

/// Figma `Avatar/Avatar` — 흰 배경 원형에 인물 이미지. 이미지 에셋이 아직 없어
/// `Fill/Alternative` 배경 + person 아이콘 플레이스홀더로 그린다(시안의 회색 자리와 동일).
struct RoomDetailAvatar: View {
    var size: CGFloat = 32
    /// 겹쳐 놓을 때 쓰는 흰 외곽선(Figma 1.5px). 단독으로 쓸 땐 false.
    var hasOuterStroke: Bool = true

    var body: some View {
        Circle()
            .fill(.mhFillAlternative)
            .overlay {
                Image(.personFill)
                    .resizable()
                    .frame(width: size * 0.5, height: size * 0.5)
                    .foregroundStyle(.mhLabelAssistive)
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

/// Figma `Avatar/Avatar Group` — 아바타를 6pt 씩 겹쳐 나열한다.
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

// MARK: - 아바타 + 추가 버튼 pill

/// Figma 헤더 좌측의 `Avatar` 인스턴스 — `Fill/Normal` pill 안에 아바타 그룹과 검정 `+` 버튼.
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

// MARK: - 썸네일 플레이스홀더

/// 카드 썸네일. 실제 이미지 에셋이 없어 회색 자리 이미지로 그린다.
/// 이미지가 붙으면 `MHThumbnail(Image(...), ...)` 로 바꾸면 된다.
struct RoomDetailThumbnail: View {
    var ratio: MHThumbnailRatio = .square

    var body: some View {
        MHThumbnail(Image(.blank), ratio: ratio, radius: true, border: true) {
            ZStack {
                // Fill/* 토큰은 반투명이라 불투명 배경 위에 얹어야 아래 플레이스홀더 이미지가 비치지 않는다
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

// MARK: - 코멘트 수

/// 카드·헤더 하단의 `아이콘 + 수치` 메타 표기.
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
