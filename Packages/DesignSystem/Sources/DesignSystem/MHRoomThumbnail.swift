import SwiftUI

/// ``MHRoomThumbnail`` 의 색상 variant. 팔레트 12색을 부르는 이름이고, 실제로 그리는 아트는
/// ``MHRoomCover`` 다(``cover``).
public enum MHRoomThumbnailColor: String, Sendable, CaseIterable, Equatable {
    case pink, purple, violet, blue, lightBlue, cyan
    case green, lime, orange, redOrange, red, brown

    /// 새 방 커버 아트(`character/RoomCover`) 짝.
    ///
    /// 케이스 이름이 같아도 `rawValue` 로 잇지 않고 여기서 명시적으로 짝짓는다 — 이름으로 이으면
    /// 한쪽 enum 이 바뀌어도 컴파일이 통과하고 런타임에 그림만 조용히 사라진다.
    var cover: MHRoomCover {
        switch self {
        case .pink: .pink
        case .purple: .purple
        case .violet: .violet
        case .blue: .blue
        case .lightBlue: .lightBlue
        case .cyan: .cyan
        case .green: .green
        case .lime: .lime
        case .orange: .orange
        case .redOrange: .redOrange
        case .red: .red
        case .brown: .brown
        }
    }
}

// MARK: - Room Thumbnail Kind

/// ``MHRoomThumbnail`` 이 그릴 표현 종류. Figma `Room Thumbnail`(wrapper, node 16798-22367)의
/// Empty(색상/my-room)·Full(사진 콜라주) 두 축을 그대로 옮긴다.
public enum MHRoomThumbnailKind: Sendable {
    /// 방 색 커버. ``MHRoomCover`` 의 색 배리언트를 그린다.
    case color(MHRoomThumbnailColor)
    /// 색이 없는 방 — 개인방(`내 장소`)과 색을 안 고른 공동방이 함께 쓴다.
    /// ``MHRoomCover/plain``(회색 실루엣)을 그린다.
    case myRoom
    /// 장소 사진 콜라주. 1~4장 레이아웃이 다르고, 4장 초과는 앞 4개만 그린다.
    /// Figma `Room Thumbnail_full`(node 16798-22357) state1~4.
    case full([Image])
    /// ``full`` 과 같은 레이아웃이되 원격 URL 을 `AsyncImage` 로 받는다.
    /// 서버가 주는 방 썸네일(`thumbnailList`)처럼 로딩이 필요한 사진에 쓴다.
    case fullRemote([URL])
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
        // URL 은 값 비교가 되므로 근사 없이 그대로 견준다.
        case let (.fullRemote(l), .fullRemote(r)): l == r
        default: false
        }
    }
}

/// 방의 기본 썸네일. Figma `Room Thumbnail`(wrapper, node 16798-22367).
///
/// 방에 지정 사진이 없을 때(Empty) 색 일러스트 또는 my-room 전용 일러스트를, 사진이 있을 때(Full)
/// 1~4장 콜라주를 그린다. 세 표현 모두 radius 는 80pt 기준 14 로 통일한다.
///
/// 색 표현은 ``MHRoomCover``(Figma `character/RoomCover`, 파스텔 정사각 위 색칠된 토끼 실루엣)를 쓴다.
///
/// - **color**: 12색 중 하나를 edge-to-edge 로 채운다.
/// - **myRoom**: 색이 없는 방 — ``MHRoomCover/plain``(회색) 하나로 채운다.
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

    /// 원격 장소 사진 콜라주. 1~4장(4장 초과는 앞 4개만 사용).
    public init(imageURLs: [URL], size: CGFloat = 80, isSelected: Bool = false) {
        self.kind = .fullRemote(imageURLs)
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
                cover(color.cover)
            case .myRoom:
                cover(.plain)
            case .full(let images):
                collage(count: images.count) { index, width, height in
                    tile(images[index], width: width, height: height)
                }
            case .fullRemote(let urls):
                collage(count: urls.count) { index, width, height in
                    remoteTile(urls[index], width: width, height: height)
                }
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

    private func cover(_ art: MHRoomCover) -> some View {
        Image(art)
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

    /// 로딩 중·실패에도 **자리가 비지 않도록** 타일 배경을 먼저 깔고 그 위에 사진을 얹는다
    /// (`MHHomeCard` 의 원격 사진과 같은 패턴 — 자리가 비면 옆 타일이 밀린다).
    private func remoteTile(_ url: URL, width: CGFloat, height: CGFloat) -> some View {
        Color.mhBackgroundNormalAlternative
            .frame(width: width, height: height)
            .overlay {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    }
                }
            }
            .clipped()
    }

    // 1/2/3/4 장 레이아웃. Figma `Room Thumbnail_full` state1~4:
    // state1=1장 꽉 채움, state2=세로 2분할, state3=좌1 풀높이+우2 세로스택, state4=2×2 그리드.
    // 4장 초과는 앞 4개만 사용한다.
    //
    // 로컬 `Image` 와 원격 `URL` 이 **같은 레이아웃을 공유**해야 해서 사진이 아니라 인덱스를 넘긴다 —
    // 타일을 무엇으로 그릴지는 부르는 쪽이 정한다.
    @ViewBuilder
    private func collage<Tile: View>(
        count: Int,
        @ViewBuilder tile: (_ index: Int, _ width: CGFloat, _ height: CGFloat) -> Tile
    ) -> some View {
        let half = (size - gap) / 2
        switch min(count, 4) {
        case 0:
            Color.mhBackgroundNormalAlternative
        case 1:
            tile(0, size, size)
        case 2:
            HStack(spacing: gap) {
                tile(0, half, size)
                tile(1, half, size)
            }
        case 3:
            HStack(spacing: gap) {
                tile(0, half, size)
                VStack(spacing: gap) {
                    tile(1, half, half)
                    tile(2, half, half)
                }
            }
        default:
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    tile(0, half, half)
                    tile(1, half, half)
                }
                HStack(spacing: gap) {
                    tile(2, half, half)
                    tile(3, half, half)
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
