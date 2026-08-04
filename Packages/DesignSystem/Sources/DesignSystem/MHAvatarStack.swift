import SwiftUI

// MARK: - Avatar Stack

/// `MHAvatarStack` 우측 트레일링. Figma `state`: default(`none`) / add(`add`) / more(`overflow`).
///
/// 셋은 상호 배타적이다(Figma variant) — 하나만 붙는다.
public enum MHAvatarStackTrailing {
    /// 트레일링 없음(아바타만). Figma `state=default`.
    case none
    /// 검정 원형 "+" 버튼(멤버 추가). Figma `state=add`.
    case add(action: () -> Void)
    /// "+N" 오버플로 카운트 배지(99 초과 시 "99+"). Figma `state=more`.
    case overflow(Int)
}

/// 참여자 아바타를 겹쳐 담은 pill. Figma `Avatar`(state = default / add / more, node 15852:88488).
///
/// 32pt 아바타를 6pt 겹쳐(선언 순서상 **오른쪽이 위**) 가로로 늘어놓고, 각 아바타 둘레에 배경색 1.5px
/// 링을 둘러 겹친 경계를 분리한다. 전체는 `Fill/Normal` pill(완전 라운드, 안쪽 여백 4pt) 안에 담긴다.
/// 우측 끝에는 `trailing` 으로 "+" 추가 버튼(`.add`)이나 "+N" 오버플로 배지(`.overflow`)를 붙일 수 있다 —
/// 트레일링도 같은 겹침 체인에 놓여 마지막 아바타와 6pt 겹친다.
///
/// 아바타 지름은 32pt 고정(Figma 단일 사이즈). 아바타 종류는 `variant` 로 바꿀 수 있고, 트레일링 배지의
/// 모양도 같은 variant 를 따라 한 줄이 균일하게 보인다.
///
/// ```swift
/// MHAvatarStack([img1, img2, img3, img4])                       // 아바타만 (default)
/// MHAvatarStack([img1]) { addMember() }                          // "+" 추가 버튼 (add)
/// MHAvatarStack([img1, img2, img3], trailing: .overflow(99))    // "99+" (more)
/// ```
public struct MHAvatarStack: View {
    private let images: [Image?]
    private let variant: MHAvatarVariant
    private let trailing: MHAvatarStackTrailing

    private let side: CGFloat = 32
    private let overlap: CGFloat = 6
    private let ringWidth: CGFloat = 1.5
    private let inset: CGFloat = 4

    public init(
        _ images: [Image?],
        variant: MHAvatarVariant = .person,
        trailing: MHAvatarStackTrailing = .none
    ) {
        self.images = images
        self.variant = variant
        self.trailing = trailing
    }

    public var body: some View {
        // 겹침: 음수 간격으로 step = side − overlap(=26). 링은 배경이라 레이아웃 폭을 늘리지 않아 겹침은 side 기준.
        HStack(spacing: -overlap) {
            ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                avatarCell(image)
            }
            trailingCell   // 트레일링도 같은 체인의 오른쪽 끝(맨 위)
        }
        .padding(inset)
        .background(Capsule().fill(.mhFillNormal))
    }

    // 아바타 1개 + 뒤에 깔린 배경색 링(둘레 1.5px, 레이아웃 비확장).
    private func avatarCell(_ image: Image?) -> some View {
        MHAvatar(image, variant: variant, size: side, badge: { EmptyView() })
            .background { ring }
    }

    @ViewBuilder private var trailingCell: some View {
        switch trailing {
        case .none:
            EmptyView()
        case .add(let action):
            addButton(action)
        case .overflow(let count):
            overflowBadge(count)
        }
    }

    // 검정 원형 "+" 버튼. Figma Button/Icon/Solid(Primary/Normal 채움, p-7, plus 18pt 흰색). 링 없음(Figma).
    private func addButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(MHIcon.plus)
                .resizable().scaledToFit()
                .frame(width: 18, height: 18)
                .foregroundStyle(.mhInversePrimary)
                .frame(width: side, height: side)
                .background(shape.fill(.mhPrimaryNormal))
                .clipShape(shape)
        }
        .buttonStyle(MHAvatarStackAddStyle(shape: shape))
    }

    /// 오버플로 배지에 표시할 텍스트. 99 이하는 그대로, 초과 시 "99+" 로 캡.
    static func overflowText(_ count: Int) -> String { count > 99 ? "99+" : "\(count)" }

    // "+N" 오버플로 배지. Figma: Background/Elevated/Alternative 채움 + 흰 링, SUITE Bold13 Label/Alternative.
    // 아바타의 1px Line 테두리는 없다(흰 링만). 99 초과 시 "99+" 로 캡.
    private func overflowBadge(_ count: Int) -> some View {
        Text(Self.overflowText(count))
            .mhTypography(.label2Bold)
            .foregroundStyle(.mhLabelAlternative)
            .frame(width: side, height: side)
            .background(shape.fill(.mhBackgroundElevatedAlternative))
            .clipShape(shape)
            .background { ring }
    }

    // 셀과 동심인 배경색 링(person=원, 그 외=둥근 사각). 배경이라 레이아웃 폭을 늘리지 않는다.
    private var ring: some View {
        shape.fill(Color.mhBackgroundNormalNormal)
            .frame(width: side + ringWidth * 2, height: side + ringWidth * 2)
    }

    // 아바타/배지/링 공통 모양. person=원(radius=16), company·academy=둥근 사각.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: variant.cornerRadius(size: side))
    }
}

// MARK: - 편의 이니셜라이저 ("+" 추가 버튼)

public extension MHAvatarStack {
    /// "+" 추가 버튼을 붙인 스택(후행 클로저). Figma `state=add`.
    init(
        _ images: [Image?],
        variant: MHAvatarVariant = .person,
        onAdd: @escaping () -> Void
    ) {
        self.init(images, variant: variant, trailing: .add(action: onAdd))
    }
}

// MARK: - ButtonStyle ("+" press 오버레이)

// 눌렀을 때: Figma `Interaction/Strong`(Static/White) 를 검정 위에 얹어 밝아진다. 정확한 불투명도는
// Figma 가 링크 페이지라 미실측 → Static/White 0.15 근사(플래그).
struct MHAvatarStackAddStyle: ButtonStyle {
    let shape: RoundedRectangle
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay {
                if configuration.isPressed {
                    shape.fill(Color.mhStaticWhite.opacity(0.15))
                }
            }
    }
}

#Preview("MHAvatarStack") {
    VStack(alignment: .leading, spacing: 16) {
        MHAvatarStack(Array(repeating: Image?.none, count: 1)) { }              // add
        MHAvatarStack(Array(repeating: Image?.none, count: 4))                  // default
        MHAvatarStack(Array(repeating: Image?.none, count: 3), trailing: .overflow(99))  // more
    }
    .padding()
}
