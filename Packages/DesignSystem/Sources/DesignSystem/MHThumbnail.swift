import SwiftUI

// MARK: - Ratio

/// 썸네일 가로세로 비(width / height). Figma `ratio` 축의 이름값들을 프리셋으로 제공하고,
/// 그 외 비율은 `MHThumbnailRatio(_:)` 로 직접 넣는다.
public struct MHThumbnailRatio: Equatable, Sendable {
    /// 가로/세로 비 (예: 16:9 → 16.0/9.0).
    public let value: CGFloat
    public init(_ value: CGFloat) { self.value = value }

    // 가로형(landscape)
    public static let square = MHThumbnailRatio(1.0 / 1.0)          // 1:1
    public static let r5x4   = MHThumbnailRatio(5.0 / 4.0)
    public static let r4x3   = MHThumbnailRatio(4.0 / 3.0)
    public static let r3x2   = MHThumbnailRatio(3.0 / 2.0)
    public static let r16x10 = MHThumbnailRatio(16.0 / 10.0)
    public static let golden = MHThumbnailRatio(1.618 / 1.0)        // 1.618:1
    public static let r16x9  = MHThumbnailRatio(16.0 / 9.0)
    public static let r2x1   = MHThumbnailRatio(2.0 / 1.0)
    public static let r21x9  = MHThumbnailRatio(21.0 / 9.0)
    // 세로형(portrait)
    public static let r4x5   = MHThumbnailRatio(4.0 / 5.0)
    public static let r3x4   = MHThumbnailRatio(3.0 / 4.0)
    public static let r2x3   = MHThumbnailRatio(2.0 / 3.0)
    public static let r10x16 = MHThumbnailRatio(10.0 / 16.0)
    public static let goldenPortrait = MHThumbnailRatio(1.0 / 1.618) // 1:1.618
    public static let r9x16  = MHThumbnailRatio(9.0 / 16.0)
    public static let r1x2   = MHThumbnailRatio(1.0 / 2.0)
    public static let r9x21  = MHThumbnailRatio(9.0 / 21.0)
}

// MARK: - Thumbnail

/// 이미지를 **항상 같은 비율**로 잘라 보여주는 썸네일. Figma `Thumbnail/Thumbnail`.
///
/// 주어진 폭을 채우고 `ratio`(가로/세로)로 높이를 정한다. 이미지는 비율에 맞춰 꽉 채워(fill) 잘린다.
/// `radius`(12pt 둥근 모서리)·`border`(1px 테두리)·`overlay`(재생 버튼·시간 배지 등 임의 오버레이) 선택.
///
/// ```swift
/// MHThumbnail(Image("cover"), ratio: .r16x9)                    // 16:9 (기본 각진 모서리)
/// MHThumbnail(Image("avatar"), ratio: .square, radius: true, border: true)  // 정사각 둥근 + 테두리
/// MHThumbnail(Image("poster"), ratio: .r3x4)                    // 세로 3:4
/// MHThumbnail(Image("ad"), ratio: .init(2.35))                  // 프리셋 밖 비율
/// MHThumbnail(Image("video"), ratio: .r16x9, radius: true) {    // 커스텀 오버레이
///     Text("12:34").mhTypography(.caption1Bold).foregroundStyle(.mhStaticWhite)
///         .padding(6).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
/// }
/// ```
public struct MHThumbnail<Overlay: View>: View {
    private let image: Image
    private let ratio: MHThumbnailRatio
    private let hasRadius: Bool
    private let border: Bool
    private let overlay: Overlay

    public init(
        _ image: Image,
        ratio: MHThumbnailRatio = .square,
        radius: Bool = false,
        border: Bool = false,
        @ViewBuilder overlay: () -> Overlay = { EmptyView() }
    ) {
        self.image = image
        self.ratio = ratio
        self.hasRadius = radius
        self.border = border
        self.overlay = overlay()
    }

    private var cornerRadius: CGFloat { hasRadius ? MHThumbnailMetric.cornerRadius : 0 }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        Color.clear
            .aspectRatio(ratio.value, contentMode: .fit)    // 폭 채우고 ratio(가로/세로)로 높이 결정
            .overlay { image.resizable().scaledToFill() }    // 비율에 맞춰 꽉 채워 자름
            .overlay { overlay }                             // 커스텀 오버레이(재생 버튼·시간 등)
            .clipShape(shape)                                // Figma overflow-clip + radius
            .overlay {
                if border {
                    shape.strokeBorder(.mhLineNormalNeutral, lineWidth: 1)
                }
            }
    }
}

// MARK: - Metric (Figma 실측)

enum MHThumbnailMetric {
    static let cornerRadius: CGFloat = 12   // radius=true 일 때 모서리
}

#Preview("MHThumbnail") {
    VStack(spacing: 16) {
        MHThumbnail(Image(systemName: "photo"), ratio: .r16x9, radius: true, border: true)
            .frame(width: 220)
        HStack(spacing: 12) {
            MHThumbnail(Image(systemName: "photo"), ratio: .square).frame(width: 90)
            MHThumbnail(Image(systemName: "photo"), ratio: .r3x4, radius: true).frame(width: 90)
        }
    }
    .padding()
}
