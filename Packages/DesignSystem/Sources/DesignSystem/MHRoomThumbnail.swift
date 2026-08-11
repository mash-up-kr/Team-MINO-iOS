import SwiftUI

/// ``MHRoomThumbnail`` 의 색상 variant. Figma `Room Thumbnail_Empty`(node 16765-22588) Property 1.
///
/// 각 색상은 전용 일러스트 에셋(`roomThumbnail_<color>`)을 그대로 그린다 — 색 배경 + 마스코트를
/// 코드에서 합성하던 이전 방식과 달리, 배경까지 포함된 완성 이미지 한 장이다.
public enum MHRoomThumbnailColor: String, Sendable, CaseIterable, Equatable {
    case pink, purple, violet, blue, lightBlue, cyan
    case green, lime, orange, redOrange, red, brown

    /// `Resources/Icon.xcassets` 의 imageset 이름. rawValue 가 접미사와 일치한다.
    var assetName: String { "roomThumbnail_\(rawValue)" }
}

public extension MHRoomThumbnailColor {
    /// 방 `color`(방 생성 시 고른 12색 중 하나) 에 해당하는 썸네일 색.
    ///
    /// 백엔드는 방 색 피커에서 고른 색 hex 를 그대로 돌려준다. `#` 유무·대소문자를 무시해 정확히
    /// 일치하는 색을 찾고, 팔레트에 없으면 `nil` — 호출부가 my-room 썸네일로 폴백한다.
    init?(roomColorHex hex: String) {
        let key = String(hex.uppercased().drop { $0 == "#" })
        guard let color = Self.paletteHex[key] else { return nil }
        self = color
    }

    /// 방 색 피커(`RoomCreationUI` 의 `roomColorSwatches`)가 쓰는 12색을 그대로 옮긴 표.
    /// 각 색은 밝은 단계(fill)와 진한 단계(선택 시 채움) 두 hex 를 갖는데, 백엔드가 어느 쪽을 보내도
    /// 매칭되도록 **둘 다** 등록한다. 값 출처는 `AtomicColor.xcassets`(피커와 같은 토큰) — 팔레트가
    /// 바뀌면 이 표도 함께 고친다.
    private static let paletteHex: [String: MHRoomThumbnailColor] = [
        "FF6363": .red,       "B00C0C": .red,
        "FF9B61": .redOrange, "C94A00": .redOrange,
        "FFC06E": .orange,    "D47800": .orange,
        "AEF779": .lime,      "429E00": .lime,
        "ACFCC7": .green,     "1ED45A": .green,
        "B5F4FF": .cyan,      "00BDDE": .cyan,
        "C0B0FF": .violet,    "6541F2": .violet,
        "FED3F7": .pink,      "FA73E3": .pink,
        "4F95FF": .blue,      "0054D1": .blue,
        "DBA679": .brown,     "B96013": .brown,
        "3DC2FF": .lightBlue, "008DCF": .lightBlue,
        "DE96FF": .purple,    "AD36E3": .purple,
    ]
}

// MARK: - Room Thumbnail Kind

/// ``MHRoomThumbnail`` 이 그릴 표현 종류. Figma `Room Thumbnail`(wrapper, node 16798-22367)의
/// Empty(색상/my-room)·Full(사진 콜라주) 두 축을 그대로 옮긴다.
public enum MHRoomThumbnailKind: Sendable {
    /// 색 일러스트. Figma `Room Thumbnail_Empty`(node 16765-22588).
    case color(MHRoomThumbnailColor)
    /// my-room 전용 일러스트(edge-to-edge). Figma `Room Thumbnail_Empty` prop1="my room".
    case myRoom
    /// 장소 사진 콜라주. 1~4장 레이아웃이 다르고, 4장 초과는 앞 4개만 그린다.
    /// Figma `Room Thumbnail_full`(node 16798-22357) state1~4.
    case full([Image])
}

extension MHRoomThumbnailKind: Equatable {
    // `Image` 는 Equatable 이 아니라 내용을 비교할 수 없다(``RoomListItem`` 의 `members: [Image?]` 비교와
    // 같은 근거). `full` 은 개수만 비교하는 근사치로 처리한다 — "장수가 바뀐 갱신"은 감지하지만, 같은
    // 장수 안에서 이미지 자체가 바뀐 변경은 이 비교로 감지하지 않는다(허용된 근사).
    public static func == (lhs: MHRoomThumbnailKind, rhs: MHRoomThumbnailKind) -> Bool {
        switch (lhs, rhs) {
        case let (.color(l), .color(r)): l == r
        case (.myRoom, .myRoom): true
        case let (.full(l), .full(r)): l.count == r.count
        default: false
        }
    }
}

/// 방의 기본 썸네일. Figma `Room Thumbnail`(wrapper, node 16798-22367).
///
/// 방에 지정 사진이 없을 때(Empty) 색 일러스트 또는 my-room 전용 일러스트를, 사진이 있을 때(Full)
/// 1~4장 콜라주를 그린다. 세 표현 모두 radius 는 80pt 기준 14 로 통일한다.
///
/// - **color**: ``MHRoomThumbnailColor`` 12색 중 하나의 완성 일러스트를 edge-to-edge 로 채운다.
/// - **myRoom**: 색 배리언트 없이 my-room 전용 일러스트 하나로 채운다.
/// - **full**: 장소 사진 1~4장을 1pt 간격 콜라주로 채운다(4장 초과는 앞 4개만).
///
/// ```swift
/// MHRoomThumbnail()                              // Pink 80pt
/// MHRoomThumbnail(color: .violet, size: 48)      // Violet 48pt
/// MHRoomThumbnail.myRoom()                       // my-room 일러스트 80pt
/// MHRoomThumbnail(images: [photo1, photo2])      // 2장 콜라주
/// ```
public struct MHRoomThumbnail: View {
    private let kind: MHRoomThumbnailKind
    private let size: CGFloat

    /// 색상 variant. 기본값 pink.
    public init(color: MHRoomThumbnailColor = .pink, size: CGFloat = 80) {
        self.kind = .color(color)
        self.size = size
    }

    /// ``MHRoomThumbnailKind`` 를 직접 지정. ``MHRoomCard`` 처럼 썸네일 종류를 주입받는 컨테이너가 쓴다.
    public init(kind: MHRoomThumbnailKind, size: CGFloat = 80) {
        self.kind = kind
        self.size = size
    }

    /// 장소 사진 콜라주. 1~4장(4장 초과는 앞 4개만 사용).
    public init(images: [Image], size: CGFloat = 80) {
        self.kind = .full(images)
        self.size = size
    }

    /// my-room 전용 일러스트 썸네일.
    public static func myRoom(size: CGFloat = 80) -> MHRoomThumbnail {
        MHRoomThumbnail(kind: .myRoom, size: size)
    }

    // Figma 80pt 기준 비율. 방 썸네일 radius 는 Card_Room 슬롯 기준(`--radius` = 14 @80pt)으로 통일한다.
    private var radius: CGFloat { size * 14 / 80 }

    // 콜라주 타일 사이 간격. Figma `Room Thumbnail_full` 실측(80pt 기준 1pt 고정, 스케일 없음).
    private let gap: CGFloat = 1

    public var body: some View {
        Group {
            switch kind {
            case .color(let color):
                image(color.assetName)
            case .myRoom:
                image("myRoomThumbnail")
            case .full(let images):
                collage(images)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius))
    }

    private func image(_ name: String) -> some View {
        Image(name, bundle: .module)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
    }

    private func tile(_ image: Image, width: CGFloat, height: CGFloat) -> some View {
        image
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
    }

    // 1/2/3/4 장 레이아웃. Figma `Room Thumbnail_full` state1~4:
    // state1=1장 꽉 채움, state2=세로 2분할, state3=좌1 풀높이+우2 세로스택, state4=2×2 그리드.
    // 4장 초과는 앞 4개만 사용한다.
    @ViewBuilder
    private func collage(_ images: [Image]) -> some View {
        let half = (size - gap) / 2
        switch images.count {
        case 0:
            Color.mhBackgroundNormalAlternative
        case 1:
            tile(images[0], width: size, height: size)
        case 2:
            HStack(spacing: gap) {
                tile(images[0], width: half, height: size)
                tile(images[1], width: half, height: size)
            }
        case 3:
            HStack(spacing: gap) {
                tile(images[0], width: half, height: size)
                VStack(spacing: gap) {
                    tile(images[1], width: half, height: half)
                    tile(images[2], width: half, height: half)
                }
            }
        default:
            let four = Array(images.prefix(4))
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    tile(four[0], width: half, height: half)
                    tile(four[1], width: half, height: half)
                }
                HStack(spacing: gap) {
                    tile(four[2], width: half, height: half)
                    tile(four[3], width: half, height: half)
                }
            }
        }
    }
}

#Preview("MHRoomThumbnail · Empty") {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(70), spacing: 10), count: 4), spacing: 10) {
        ForEach(MHRoomThumbnailColor.allCases, id: \.self) { color in
            MHRoomThumbnail(color: color, size: 70)
        }
        MHRoomThumbnail.myRoom(size: 70)
    }
    .padding()
}

#Preview("MHRoomThumbnail · Full") {
    let photo = Image(systemName: "photo")
    return LazyVGrid(columns: Array(repeating: GridItem(.fixed(70), spacing: 10), count: 4), spacing: 10) {
        MHRoomThumbnail(images: [photo], size: 70)
        MHRoomThumbnail(images: [photo, photo], size: 70)
        MHRoomThumbnail(images: [photo, photo, photo], size: 70)
        MHRoomThumbnail(images: [photo, photo, photo, photo], size: 70)
    }
    .padding()
}
