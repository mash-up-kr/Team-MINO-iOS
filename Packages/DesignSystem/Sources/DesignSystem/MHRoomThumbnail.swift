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
    private let isSelected: Bool

    /// 색상 variant. 기본값 pink.
    public init(color: MHRoomThumbnailColor = .pink, size: CGFloat = 80, isSelected: Bool = false) {
        self.kind = .color(color)
        self.size = size
        self.isSelected = isSelected
    }

    /// ``MHRoomThumbnailKind`` 를 직접 지정. ``MHRoomCard`` 처럼 썸네일 종류를 주입받는 컨테이너가 쓴다.
    public init(kind: MHRoomThumbnailKind, size: CGFloat = 80, isSelected: Bool = false) {
        self.kind = kind
        self.size = size
        self.isSelected = isSelected
    }

    /// 장소 사진 콜라주. 1~4장(4장 초과는 앞 4개만 사용).
    public init(images: [Image], size: CGFloat = 80, isSelected: Bool = false) {
        self.kind = .full(images)
        self.size = size
        self.isSelected = isSelected
    }

    /// my-room 전용 일러스트 썸네일.
    public static func myRoom(size: CGFloat = 80, isSelected: Bool = false) -> MHRoomThumbnail {
        MHRoomThumbnail(kind: .myRoom, size: size, isSelected: isSelected)
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
        .overlay { if isSelected { selectedOverlay } }
    }

    /// 선택 표시 — 딤(검정 40%) 위에 흰 체크. Figma `Room Thumbnail` property2="select"(node 3251-202525).
    /// 체크는 썸네일 크기에 비례한다(Figma 70pt 기준 28 → 80pt 기준 32).
    private var selectedOverlay: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.black.opacity(0.4))
            .overlay {
                Image(MHIcon.checkThick)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.4, height: size * 0.4)
                    .foregroundStyle(.mhStaticWhite)
            }
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
