import SwiftUI

/// 참여자 아바타를 겹쳐 담은 pill. Figma `Avatar`(state = default / add / more, node 15852:88488).
///
/// 32pt 아바타를 6pt 겹쳐(선언 순서상 **오른쪽이 위**) 가로로 늘어놓고, 각 아바타 둘레에 배경색 1.5px
/// 링을 둘러 겹친 경계를 분리한다. 전체는 `Fill/Normal` pill(완전 라운드, 안쪽 여백 4pt) 안에 담긴다.
/// 우측 끝에는 "+N" 카운터 칩(`overflow`)과 "+" 추가 버튼(`onAdd`)을 붙일 수 있다 — **둘은 함께
/// 놓일 수 있다.** 순서는 아바타 → 카운터 → `+` 다: PRD 「방 멤버 아바타」가 "카운터 칩은 그
/// 아바타의 오른쪽에 붙인다" 로 정했고, 조작 버튼인 `+` 를 맨 끝에 둔다. 트레일링도 같은 겹침
/// 체인에 놓여 마지막 아바타와 6pt 겹친다.
///
/// 아바타 지름은 32pt 고정(Figma 단일 사이즈). 아바타 종류는 `variant` 로 바꿀 수 있고, 트레일링 배지의
/// 모양도 같은 variant 를 따라 한 줄이 균일하게 보인다.
///
/// ```swift
/// MHAvatarStack([img1, img2, img3, img4])                        // 아바타만
/// MHAvatarStack([img1], onAdd: { addMember() })                  // "+" 추가 버튼
/// MHAvatarStack([img1, img2, img3], overflow: 99)                // "99+" 카운터
/// MHAvatarStack([img1, img2, img3], overflow: 4, onAdd: { ... }) // 카운터 + "+"
/// ```
public struct MHAvatarStack: View {
    private let images: [Image?]
    private let variant: MHAvatarVariant
    /// 아바타로 보이지 않는 나머지 인원. `nil` 이면 카운터를 붙이지 않는다(4명 이하).
    private let overflow: Int?
    /// 멤버 초대. `nil` 이면 `+` 를 붙이지 않는다(개인방은 초대 불가).
    private let onAdd: (() -> Void)?

    private let side: CGFloat = 32
    private let overlap: CGFloat = 6
    private let ringWidth: CGFloat = 1.5
    private let inset: CGFloat = 4

    public init(
        _ images: [Image?],
        variant: MHAvatarVariant = .person,
        overflow: Int? = nil,
        onAdd: (() -> Void)? = nil
    ) {
        self.images = images
        self.variant = variant
        self.overflow = overflow
        self.onAdd = onAdd
    }

    public var body: some View {
        HStack(spacing: -overlap) {
            ForEach(Array(images.enumerated()), id: \.offset) { _, image in
                avatarCell(image)
            }
            trailingCell
        }
        .padding(inset)
        .background(Capsule().fill(.mhFillNormal))
    }

    private func avatarCell(_ image: Image?) -> some View {
        MHAvatar(image, variant: variant, size: side, badge: { EmptyView() })
            .background { ring }
    }

    // 카운터와 `+` 는 상호배타가 아니다 — 5명 이상인 공동방은 둘이 함께 선다.
    @ViewBuilder private var trailingCell: some View {
        if let overflow {
            MHAvatarCountBadge(remaining: overflow, variant: variant, side: side)
        }
        if let onAdd {
            addButton(onAdd)
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
        // 라벨을 주지 않으면 에셋 이름("plus")이 그대로 읽힌다.
        .accessibilityLabel("멤버 초대")
        // 식별자는 **버튼이 자기 이름을 갖는다**(`MHActionArea.main` 과 같은 규칙). 쓰는 화면이
        // pill 에 걸면 SwiftUI 가 자식 전체로 전파해 아바타까지 같은 이름이 되고, 자동화가
        // "+ 를 눌러라" 를 지목할 수 없다(시뮬레이터에서 2개 매칭 확인).
        .accessibilityIdentifier("MHAvatarStack.add")
    }

    private var ring: some View {
        shape.fill(Color.mhBackgroundNormalNormal)
            .frame(width: side + ringWidth * 2, height: side + ringWidth * 2)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: variant.cornerRadius(size: side))
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
                    shape.fill(Color.mhInversePrimary.opacity(0.15))
                }
            }
    }
}

#Preview("MHAvatarStack") {
    VStack(alignment: .leading, spacing: 16) {
        MHAvatarStack(Array(repeating: Image?.none, count: 1), onAdd: { })          // 1명 + 초대
        MHAvatarStack(Array(repeating: Image?.none, count: 4))                      // 4명 — 카운터 없음
        MHAvatarStack(Array(repeating: Image?.none, count: 3), overflow: 4)         // 7명 → 3 + "4"
        MHAvatarStack(Array(repeating: Image?.none, count: 3), overflow: 4, onAdd: { })
        MHAvatarStack(Array(repeating: Image?.none, count: 3), overflow: 100)       // "99+" 로 캡
    }
    .padding()
}
