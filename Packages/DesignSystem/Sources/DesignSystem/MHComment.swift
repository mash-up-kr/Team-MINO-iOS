import SwiftUI

/// 작성자(아바타 + 이름)와 코멘트 본문을 보여주는 표시형 컴포넌트. Figma `comment`(node 15852:88585).
///
/// 상단에 32pt 아바타와 이름, 아래에 본문을 둔다. 본문은 `maxBodyHeight`(기본 140pt)를 넘으면 말줄임 없이
/// 그대로 **잘린다**(Figma overflow-clip). Figma 의 normal/half/full 상태는 본문 길이 차이일 뿐 한 컴포넌트다.
///
/// > 본문 색은 Figma 가 raw `#000000` 을 쓰지만, 라이트에서 사실상 동일하고 다크 대응을 위해 `Label/Normal`
/// > 토큰으로 매핑했다.
///
/// 이름 행 우측의 더보기(⋮)는 `menuItems`(``MHMenuItem``)를 주면 나타난다 — Figma 가 케밥 있는 행
/// (`Frame 124`)과 없는 행(`Frame 125`)을 한 컴포넌트의 두 모습으로 두었기 때문에, 항목이 비면
/// 아예 그리지 않는다. 눌리면 ⋮ 아래에 앵커된 ``MHMenu`` 가 열리고, 항목 선택·⋮ 재탭·바깥 탭으로 닫힌다.
/// 외부에서 여닫음을 제어하려면 `menuPresented` 바인딩을 준다(미지정 시 내부 상태로 관리).
///
/// > **목록에서 한 번에 하나만 열기**: 각 코멘트가 내부 상태를 쓰면 여러 개가 동시에 열린다.
/// > 컨테이너가 "열린 코멘트 식별자" 하나를 들고 각 코멘트에 그로부터 파생한 바인딩을 주면
/// > 다른 코멘트를 열 때 이전 것이 자동으로 닫힌다(``MHLocationCard`` 와 같은 규약).
///
/// > 메뉴가 열린 모습은 ``MHMenu`` 와 동일하게 `ImageRenderer` 로는 렌더되지 않아 **시뮬레이터로만
/// > 육안 확인**된다.
///
/// ```swift
/// MHComment(avatar: Image("me"), name: "이름", comment: "친구가 남긴 코멘트입니다.")
/// MHComment(avatar: nil, name: "이름", comment: longText) { openProfile() }   // 아바타 탭
/// MHComment(avatar: nil, name: "이름", comment: body,
///           menuItems: [MHMenuItem("댓글 삭제") { delete() }],
///           menuPresented: $isOpen)                                          // 케밥 + 메뉴
/// ```
public struct MHComment: View {
    private let avatar: Image?
    private let name: String
    private let comment: String
    private let maxBodyHeight: CGFloat
    private let menuItems: [MHMenuItem]
    private let externalMenuPresented: Binding<Bool>?
    private let moreButtonLabel: String
    private let onAvatarTap: (() -> Void)?

    @State private var internalMenuPresented = false

    public init(
        avatar: Image?,
        name: String,
        comment: String,
        maxBodyHeight: CGFloat = 140,
        menuItems: [MHMenuItem] = [],
        menuPresented: Binding<Bool>? = nil,
        moreButtonLabel: String = "더보기",
        onAvatarTap: (() -> Void)? = nil
    ) {
        self.avatar = avatar
        self.name = name
        self.comment = comment
        self.maxBodyHeight = maxBodyHeight
        self.menuItems = menuItems
        self.externalMenuPresented = menuPresented
        self.moreButtonLabel = moreButtonLabel
        self.onAvatarTap = onAvatarTap
    }

    private var hasMenu: Bool { !menuItems.isEmpty }

    // 외부 바인딩이 있으면 그걸, 없으면 내부 상태를 여닫음 소스로 쓴다.
    private var menuPresented: Binding<Bool> {
        externalMenuPresented ?? $internalMenuPresented
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                MHAvatar(avatar, size: 32, action: onAvatarTap)
                Text(name)
                    .mhTypography(.label1NormalMedium)
                    .foregroundStyle(.mhLabelAlternative)
                if hasMenu {
                    Spacer(minLength: 8)
                    moreButton
                }
            }
            Text(comment)
                .lineLimit(nil)                        // Text→View + 줄 수 무제한(뒤 .mhTypography 가 행간 박스를 얻게)
                .mhTypography(.label1NormalRegular)
                .foregroundStyle(.mhLabelNormal)
                .fixedSize(horizontal: false, vertical: true)   // 전체 높이로 레이아웃 → 말줄임(…) 대신 하드 클립
                .frame(maxWidth: .infinity, maxHeight: maxBodyHeight, alignment: .topLeading)
                .clipped()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay { dismissScrim }                         // 바깥 탭 감지(메뉴 아래 레이어)
        .overlay(alignment: .topTrailing) { menuOverlay }  // 메뉴(스크림 위)
        // 메뉴가 열린 코멘트를 형제(아래 코멘트) 위로 올린다 — 아래 코멘트가 열린 메뉴를 가리지 않도록.
        .zIndex(menuPresented.wrappedValue ? 1 : 0)
    }

    // 더보기(⋮) — 배경 없는 18pt 아이콘. Figma 가 `Label/Normal`(#171719)로 찍어 둔 자리라
    // `MHLocationCard` 의 ⋮(Label/Alternative)보다 진하다.
    private var moreButton: some View {
        Button {
            withAnimation(.easeOut(duration: Metric.animation)) { menuPresented.wrappedValue.toggle() }
        } label: {
            Image(MHIcon.moreVertical)
                .resizable().scaledToFit()
                .frame(width: Metric.iconSize, height: Metric.iconSize)
                .foregroundStyle(.mhLabelNormal)
                // 히트 영역을 44pt 로 넓히되(투명 영역까지 탭 인식) 레이아웃 폭은 아이콘 크기로
                // 되돌린다 — 32pt 인 이름 행이 버튼 높이에 끌려 늘어나지 않게.
                .frame(width: Metric.hitSize, height: Metric.hitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: Metric.iconSize, height: Metric.iconSize)
        .accessibilityLabel(moreButtonLabel)
    }

    // 메뉴 바깥을 탭하면 닫는 투명 스크림. 화면 전체를 덮도록 크게 잡되(레이아웃엔 영향 없음),
    // 색이 없어 보이지 않는다. 메뉴는 이 위에 별도 오버레이로 얹혀 항목 탭은 그대로 동작한다.
    @ViewBuilder private var dismissScrim: some View {
        if menuPresented.wrappedValue, hasMenu {
            Color.clear
                .frame(width: 10000, height: 10000)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: Metric.animation)) { menuPresented.wrappedValue = false }
                }
        }
    }

    // ⋮ 에 앵커된 메뉴 — 트레일링 정렬로 ⋮ 오른쪽 끝에 붙고, ⋮ 바로 아래로 편다.
    @ViewBuilder private var menuOverlay: some View {
        if menuPresented.wrappedValue, hasMenu {
            MHMenu(closableMenuItems)
                .frame(width: Metric.menuWidth)
                .offset(y: Metric.menuTopOffset)
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
                menuPresented.wrappedValue = false
            }
        }
    }

    private enum Metric {
        static let iconSize: CGFloat = 18
        static let hitSize: CGFloat = 44
        static let menuWidth: CGFloat = 140
        /// 이름 행(32pt) 안에서 세로 중앙인 ⋮ 의 아래끝(7 + 18)에 1pt 를 띄운 값. Figma 실측과 같다.
        static let menuTopOffset: CGFloat = 26
        static let animation: TimeInterval = 0.12
    }
}

#Preview("MHComment") {
    let short = "친구가 남긴 코멘트입니다."
    let long = String(repeating: "친구가 남긴 코멘트입니다.", count: 20)
    return VStack(alignment: .leading, spacing: 24) {
        MHComment(avatar: nil, name: "이름", comment: short)
        MHComment(avatar: nil, name: "이름", comment: long)   // 140pt 에서 잘림
    }
    .frame(width: 335)
    .padding()
}

#Preview("MHComment — 케밥 메뉴") {
    struct Host: View {
        @State private var openIndex: Int?
        var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(0..<3) { i in
                    MHComment(
                        avatar: nil,
                        name: "이름 \(i)",
                        comment: String(repeating: "친구가 남긴 코멘트입니다.", count: i + 1),
                        menuItems: [MHMenuItem("댓글 삭제") {}],
                        menuPresented: Binding(
                            get: { openIndex == i },
                            set: { openIndex = $0 ? i : nil }
                        ),
                        moreButtonLabel: "이름 \(i) 코멘트 더보기"
                    )
                    .zIndex(openIndex == i ? 1 : 0)
                }
            }
            .frame(width: 335)
            .padding()
        }
    }
    return Host()
}
