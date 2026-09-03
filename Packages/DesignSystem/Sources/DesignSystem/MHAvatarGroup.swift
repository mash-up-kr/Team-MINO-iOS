import SwiftUI

/// 아바타 그룹 크기. Figma `size` = XSmall(24) / Small(32) — 그룹 전용 2종.
///
/// 겹침(overlap)은 크기의 0.25배(XSmall 6 / Small 8), trailing 콘텐츠와의 간격은 XSmall 8 / Small 10.
public enum MHAvatarGroupSize: Sendable {
    case xSmall, small

    /// 아바타 지름(pt). XSmall 24 / Small 32.
    var pt: CGFloat { self == .xSmall ? 24 : 32 }
    /// 이웃 아바타끼리 겹치는 폭 = 크기×0.25 (XSmall 6 / Small 8).
    var overlap: CGFloat { pt * 0.25 }
    /// 아바타 묶음과 trailing 콘텐츠 사이 간격 (XSmall 8 / Small 10).
    var trailingGap: CGFloat { self == .xSmall ? 8 : 10 }
}

/// 그룹화된 다수의 아바타를 겹쳐 표시한다. Figma `Avatar/Avatar Group`.
///
/// 아바타를 크기×0.25 만큼 겹쳐 가로로 늘어놓고, 각 아바타 둘레에 배경색 1.5px 링을 둘러 겹친 경계를
/// 분리한다(뒤 아바타 위에 앞 아바타가 얹히도록 **오른쪽이 위**). 오른쪽 끝에는 "외 N명" 같은
/// `trailing` 콘텐츠를 붙일 수 있다.
///
/// ```swift
/// MHAvatarGroup([img1, img2, img3], size: .small)                 // 이미지 3개
/// MHAvatarGroup([img1, img2], variant: .company, size: .xSmall)   // 기관(둥근 사각)
/// MHAvatarGroup([img1, img2, img3, img4, img5], remaining: 12)     // "외 12명" 라벨
/// MHAvatarGroup([img1, img2], size: .small) { myTrailingView }     // 커스텀 trailing
/// ```
public struct MHAvatarGroup<Trailing: View>: View {
    private let images: [Image?]
    private let variant: MHAvatarVariant
    private let size: MHAvatarGroupSize
    private let trailing: Trailing

    private let ringWidth: CGFloat = 1.5   // Figma: 각 아바타 배경색 링 1.5px

    public init(
        _ images: [Image?],
        variant: MHAvatarVariant = .person,
        size: MHAvatarGroupSize = .small,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.images = images
        self.variant = variant
        self.size = size
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: size.trailingGap) {
            // 겹침: 음수 간격으로 step = 크기 − overlap(=크기×0.75). 선언 순서상 오른쪽이 위(뒤 위에 앞).
            HStack(spacing: -size.overlap) {
                ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                    cell(image)
                }
            }
            trailing
        }
    }

    // 아바타 1개 + 뒤에 깔린 배경색 링(둘레 1.5px). 링은 레이아웃 폭을 늘리지 않아(배경) 겹침 계산은 크기 기준.
    private func cell(_ image: Image?) -> some View {
        let side = size.pt
        return MHAvatar(image, variant: variant, size: side, badge: { EmptyView() })
            .background { ring.frame(width: side + ringWidth * 2, height: side + ringWidth * 2) }
    }

    // 아바타와 동심인 배경색 링(person=원, 그 외=둥근 사각 — 아바타 모서리 + 1.5 로 동심 유지).
    @ViewBuilder private var ring: some View {
        let color = Color.mhBackgroundNormalNormal
        if variant == .person {
            Circle().fill(color)
        } else {
            RoundedRectangle(cornerRadius: variant.cornerRadius(size: size.pt) + ringWidth).fill(color)
        }
    }
}

// MARK: - 편의 이니셜라이저 ("외 N명" 라벨)

public extension MHAvatarGroup where Trailing == MHAvatarGroupCountLabel {
    /// 아바타 묶음 뒤에 "외 N명" 라벨(Figma 기본 trailing)을 붙인 그룹.
    init(
        _ images: [Image?],
        variant: MHAvatarVariant = .person,
        size: MHAvatarGroupSize = .small,
        remaining: Int
    ) {
        self.init(images, variant: variant, size: size) {
            MHAvatarGroupCountLabel(remaining: remaining)
        }
    }
}

/// Avatar Group 의 기본 trailing 라벨 "외 N명". Figma `Trailing Content/Text`(SUITE Bold 14, Label/Alternative).
public struct MHAvatarGroupCountLabel: View {
    private let remaining: Int
    public init(remaining: Int) { self.remaining = remaining }

    public var body: some View {
        Text("외 \(remaining)명")
            .mhTypography(.label1NormalBold)
            .foregroundStyle(.mhLabelAlternative)
            .padding(.vertical, 4)   // Figma: py-[4px]
    }
}

#Preview("MHAvatarGroup") {
    VStack(alignment: .leading, spacing: 20) {
        MHAvatarGroup(Array(repeating: Image?.none, count: 4), size: .xSmall)
        MHAvatarGroup(Array(repeating: Image?.none, count: 5), size: .small)
        MHAvatarGroup(Array(repeating: Image?.none, count: 5), size: .small, remaining: 12)
    }
    .padding()
}
