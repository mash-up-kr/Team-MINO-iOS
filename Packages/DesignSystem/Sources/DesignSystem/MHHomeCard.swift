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
/// ```
public struct MHHomeCard: View {
    private let avatar: Image?
    private let badgeText: String
    private let badgeColor: Color
    private let title: String
    private let address: String
    private let images: [Image]
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
        self.images = images
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
        .overlay { dismissScrim }                          // 메뉴 바깥 탭 감지(메뉴 아래 레이어)
        .overlay(alignment: .topTrailing) { menuOverlay }  // ⋮ 에 앵커된 더보기 메뉴(스크림 위)
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

    // 메뉴 바깥을 탭하면 닫는 투명 스크림(레이아웃 영향 없음). 메뉴는 이 위에 별도 오버레이로 얹힌다.
    @ViewBuilder private var dismissScrim: some View {
        if menuPresented, !menuItems.isEmpty {
            Color.clear
                .frame(width: 10000, height: 10000)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.12)) { menuPresented = false }
                }
        }
    }

    // ⋮ 에 앵커된 더보기 메뉴(Figma `Menu/Menu`, node 2862:175604). Menu/Menu 는 흰 카드 위아래로 투명 패딩 8pt 를
    // 가지므로, 카드만 그리는 MHMenu 에 vertical 8 을 씌워 재현하고 우상단 실측 오프셋으로 카드에 앵커한다.
    // 선택 시 액션 실행 후 자동으로 닫힌다.
    @ViewBuilder private var menuOverlay: some View {
        if menuPresented, !menuItems.isEmpty {
            MHMenu(closableMenuItems)
                .frame(width: 140)
                .padding(.vertical, 8)
                .offset(x: -25.42, y: 47.12)
                .transition(.opacity)
        }
    }

    // 원본 항목의 액션 뒤에 "메뉴 닫기"를 덧붙인 사본(선택하면 닫히도록).
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

    private var imageGrid: some View {
        HStack(spacing: 8) {
            if images.isEmpty {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.mhBackgroundNormalAlternative)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(147.5 / 184, contentMode: .fit)
                }
            } else {
                ForEach(Array(images.prefix(2).enumerated()), id: \.offset) { _, image in
                    image
                        .resizable().scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 184)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
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
