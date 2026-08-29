import SwiftUI

/// 홈에서 쓰는 장소 카드. Figma `Card_Home`(node 15852:88604).
///
/// 상단에 작성자 아바타 + 추천 이유 뱃지(강조색) + 더보기 버튼, 그 아래 제목·주소, 마지막에 사진 2장을
/// 나란히 보여준다. Figma 의 4개 variant 는 뱃지의 문구·강조색만 다르므로 `badgeText`·`badgeColor` 로 받는다
/// (예: 클릭률순=Light Blue, 코멘트순=Pink, 저장겹침=Red Orange, 기본=Lime).
///
/// ```swift
/// MHHomeCard(
///     avatar: Image("me"), badgeText: "친구들이 많이 본 곳", badgeColor: .mhAccentForegroundLightBlue,
///     title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10", images: [img1, img2]
/// ) { openMore() }
///
/// MHHomeCard(
///     avatar: Image("me"), badgeText: "친구들이 많이 본 곳", badgeColor: .mhAccentForegroundLightBlue,
///     title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10", imageURLs: pin.images
/// ) { openMore() }
/// ```
public struct MHHomeCard: View {
    // 로컬(Image)·원격(URL) 두 init 이 그릴 소스를 하나로 수렴시킨 표현. imageGrid 는 이것만 본다.
    private enum ImageSource {
        case local([Image])
        case remote([URL])

        var isEmpty: Bool {
            switch self {
            case .local(let images): return images.isEmpty
            case .remote(let urls): return urls.isEmpty
            }
        }
    }

    private let avatar: Image?
    private let badgeText: String
    private let badgeColor: Color
    private let title: String
    private let address: String
    private let imageSource: ImageSource
    private let menuItems: [MHMenuItem]
    private let onMore: (() -> Void)?

    @State private var menuPresented = false

    public init(
        avatar: Image?,
        badgeText: String,
        badgeColor: Color,
        title: String,
        address: String,
        images: [Image],
        menuItems: [MHMenuItem] = [],
        onMore: (() -> Void)? = nil
    ) {
        self.avatar = avatar
        self.badgeText = badgeText
        self.badgeColor = badgeColor
        self.title = title
        self.address = address
        self.imageSource = .local(images)
        self.menuItems = menuItems
        self.onMore = onMore
    }

    /// 원격 사진(`Pin.images` 등)을 `AsyncImage` 로 그리는 버전. 로딩 중·실패는 같은 자리표로 받는다
    /// (자리가 비면 옆 사진이 밀리기 때문) — `PlaceDetailPhotoCarousel.photo(_:)` 와 같은 패턴.
    public init(
        avatar: Image?,
        badgeText: String,
        badgeColor: Color,
        title: String,
        address: String,
        imageURLs: [URL],
        menuItems: [MHMenuItem] = [],
        onMore: (() -> Void)? = nil
    ) {
        self.avatar = avatar
        self.badgeText = badgeText
        self.badgeColor = badgeColor
        self.title = title
        self.address = address
        self.imageSource = .remote(imageURLs)
        self.menuItems = menuItems
        self.onMore = onMore
    }

    public var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack(spacing: 0) {
                    HStack(spacing: 8) {
                        MHAvatar(avatar, size: 32)
                        MHContentBadge(badgeText, variant: .solid, size: .medium, color: badgeColor)
                    }
                    Spacer(minLength: 0)
                    moreButton
                }
                info
            }
            imageGrid
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color.mhBackgroundNormalNormal))
        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.mhBackgroundNormalAlternative, lineWidth: 1))
        // 더보기 메뉴는 카드 overlay 로 그리지 않는다 — 콘텐츠 크기인 카드는 바깥탭 dismiss 스크림을
        // 화면 전체로 펼칠 수 없기 때문(overlay 는 카드 크기를 제안). 대신 카드 위치(앵커)와 메뉴 내용을
        // preference 로 발행하고, 화면을 채우는 조상의 `mhHomeCardMenuHost()` 가 최상위에 스크림+메뉴를 렌더한다.
        .anchorPreference(key: MHHomeCardMenuKey.self, value: .bounds) { anchor in
            menuPresented && !menuItems.isEmpty
                ? MHHomeCardMenuPresentation(
                    anchor: anchor,
                    items: closableMenuItems,
                    dismiss: { withAnimation(.easeOut(duration: 0.12)) { menuPresented = false } }
                )
                : nil
        }
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 2) {
            line(title, .body1NormalBold, .mhLabelNormal)
            line(address, .label2Regular, .mhLabelAlternative)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func line(_ string: String, _ token: MHTypography, _ color: Color) -> some View {
        Text(string)
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(color)
            .mhTypography(token)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var moreButton: some View {
        Button {
            if menuItems.isEmpty {
                onMore?()
            } else {
                withAnimation(.easeOut(duration: 0.12)) { menuPresented.toggle() }
            }
        } label: {
            Image(MHIcon.moreVertical)
                .resizable().scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(.mhLabelNormal)   // Figma node 2598:97055 — Label/Normal
                .frame(width: 32, height: 32)      // 배경 원 없이 아이콘만(32 히트영역)
                .contentShape(Rectangle())
        }
        .buttonStyle(MHHomeCardMoreStyle())
    }

    // 원본 항목의 액션 뒤에 "메뉴 닫기"를 덧붙인 사본(선택하면 닫히도록). 호스트(mhHomeCardMenuHost)가 렌더한다.
    private var closableMenuItems: [MHMenuItem] {
        menuItems.map { item in
            MHMenuItem(
                item.label, caption: item.caption, trailing: item.trailing,
                isActive: item.isActive, isDisabled: item.isDisabled
            ) {
                item.action()
                menuPresented = false
            }
        }
    }

    @ViewBuilder
    private var imageGrid: some View {
        HStack(spacing: 8) {
            switch imageSource {
            case .local(let images) where !images.isEmpty:
                ForEach(Array(images.prefix(2).enumerated()), id: \.offset) { _, image in
                    imageTile { image.resizable().scaledToFill() }
                }
            case .remote(let urls) where !urls.isEmpty:
                ForEach(Array(urls.prefix(2).enumerated()), id: \.offset) { _, url in
                    imageTile {
                        AsyncImage(url: url) { phase in
                            // 로딩 중·실패는 그리지 않는다 — 자리표는 타일 자신의 배경이라
                            // 어느 단계에서도 자리가 비지 않는다.
                            if case .success(let image) = phase {
                                image.resizable().scaledToFill()
                            }
                        }
                    }
                }
            default:
                ForEach(0..<2, id: \.self) { _ in imageTile { EmptyView() } }
            }
        }
    }

    /// 사진 한 칸. **자리(비율)가 먼저 정해지고 사진은 그 안에 얹힌다.**
    ///
    /// 사진을 레이아웃에 직접 태우면(`Image` 를 그대로 HStack 자식으로) 원본 픽셀 크기가 카드 폭을
    /// 밀어낸다. 홈 덱은 실측 컨테이너 폭으로 카드 폭을 정하므로(`CardDeckView.widthReader`) 그
    /// 부풀어 오른 폭이 다시 읽혀 덱 전체가 화면 밖으로 나간다 — 시뮬레이터에서 재현했다.
    /// 그래서 크기는 언제나 이 타일이 정하고, 사진은 `overlay` 로 얹은 뒤 넘치는 부분을 잘라낸다.
    private func imageTile<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.mhBackgroundNormalAlternative)
            .aspectRatio(147.5 / 184, contentMode: .fit)
            .overlay { content() }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - 더보기 메뉴 화면 레벨 호스팅

// Figma `Menu/Menu` 실측 — 앵커(카드 우상단) 기준 메뉴 크기·오프셋.
private enum MHHomeCardMenuMetrics {
    static let width: CGFloat = 140
    static let verticalPadding: CGFloat = 8
    static let anchorInsetX: CGFloat = 25.42    // 카드 우측 끝에서 안쪽으로
    static let anchorOffsetY: CGFloat = 47.12   // 카드 상단에서 아래로
}

/// `MHHomeCard` 가 발행하는 더보기 메뉴 표시 정보. `mhHomeCardMenuHost()` 가 화면 최상위에 렌더한다.
struct MHHomeCardMenuPresentation {
    let anchor: Anchor<CGRect>
    let items: [MHMenuItem]
    let dismiss: () -> Void
}

// 하위 카드 중 '열린' 카드 하나가 자기 표시 정보를 발행한다(닫힌 카드는 nil → 최신 non-nil 유지).
struct MHHomeCardMenuKey: PreferenceKey {
    // 값(클로저 포함)이 non-Sendable 이라 strict concurrency 가 static 을 막지만, 상수 nil 이라 공유 가변 상태가 없다.
    nonisolated(unsafe) static let defaultValue: MHHomeCardMenuPresentation? = nil
    static func reduce(value: inout MHHomeCardMenuPresentation?, nextValue: () -> MHHomeCardMenuPresentation?) {
        value = nextValue() ?? value
    }
}

public extension View {
    /// 화면을 채우는 조상에 붙여, 하위 `MHHomeCard` 의 더보기 메뉴를 **화면 최상위**에 띄운다.
    ///
    /// 콘텐츠 크기인 카드의 overlay 로는 바깥탭 dismiss 스크림을 화면 전체로 펼칠 수 없어(overlay 는
    /// 카드 크기를 제안), 메뉴·스크림 렌더를 화면 레벨로 올린다. z-order(스크림 위=콘텐츠, 스크림 아래=메뉴)와
    /// 바깥탭 닫기를 정확히 관리하며, 매직 넘버 스크림 없이 화면을 덮는다.
    func mhHomeCardMenuHost() -> some View {
        overlayPreferenceValue(MHHomeCardMenuKey.self) { presentation in
            GeometryReader { proxy in
                if let presentation {
                    let card = proxy[presentation.anchor]
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { presentation.dismiss() }   // 카드 밖 어디를 눌러도 닫힘
                        MHMenu(presentation.items)
                            .frame(width: MHHomeCardMenuMetrics.width)
                            .padding(.vertical, MHHomeCardMenuMetrics.verticalPadding)
                            .offset(
                                x: card.maxX - MHHomeCardMenuMetrics.width - MHHomeCardMenuMetrics.anchorInsetX,
                                y: card.minY + MHHomeCardMenuMetrics.anchorOffsetY
                            )
                            .transition(.opacity)
                    }
                }
            }
            .ignoresSafeArea()   // 스크림이 카드 밖 화면 전체를 덮게 — 매직 넘버 프레임 대체
        }
    }
}

// Figma `Interaction/Strong`(Label/Normal) — 눌림 시 원 위에 옅게 덮는다.
struct MHHomeCardMoreStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                if configuration.isPressed {
                    Circle().fill(Color.mhLabelNormal.opacity(0.09)).frame(width: 32, height: 32)
                }
            }
    }
}

#Preview("MHHomeCard") {
    MHHomeCard(
        avatar: nil,
        badgeText: "친구들이 많이 본 곳",
        badgeColor: .mhAccentForegroundLightBlue,
        title: "레이어스튜디오 10",
        address: "서울 성동구 상원4길 10",
        images: []
    ) { }
    .frame(width: 335)
    .padding()
}

#Preview("MHHomeCard - Remote") {
    MHHomeCard(
        avatar: nil,
        badgeText: "친구들이 많이 본 곳",
        badgeColor: .mhAccentForegroundLightBlue,
        title: "레이어스튜디오 10",
        address: "서울 성동구 상원4길 10",
        imageURLs: [
            URL(string: "https://picsum.photos/seed/gguk-0-0/800/600")!,
            URL(string: "https://picsum.photos/seed/gguk-0-1/800/600")!,
        ]
    ) { }
    .frame(width: 335)
    .padding()
}
