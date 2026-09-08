import SwiftUI

/// 겹친 아바타 줄 끝에 붙는 "+N" 카운터 칩. Figma `Avatar` state=more 의 배지.
///
/// PRD 「방 멤버 아바타」 — "**5명 이상**: 아바타 3개 + **카운터 칩**으로 표시한다. 카운터는
/// **아바타로 보이지 않는 나머지 인원 수**다(멤버 7명 → 아바타 3개 + `4`). 나머지 인원이 99명을
/// 넘으면 `99+` 로 표기한다."
///
/// ``MHAvatarStack``(방 상세 헤더의 32pt pill)과 ``MHAvatarGroup``(방 카드의 24pt 줄)이 함께
/// 쓴다 — 같은 규칙을 두 벌로 두면 한쪽만 고쳐도 컴파일이 통과한다.
public struct MHAvatarCountBadge: View {
    /// 아바타로 보이지 않는 나머지 인원.
    private let remaining: Int
    private let variant: MHAvatarVariant
    private let side: CGFloat
    /// 아바타와 같은 배경색 링을 둘러 겹친 경계를 분리할지. 아바타와 겹쳐 놓일 때만 켠다.
    private let showsRing: Bool

    private let ringWidth: CGFloat = 1.5

    public init(
        remaining: Int,
        variant: MHAvatarVariant = .person,
        side: CGFloat,
        showsRing: Bool = true
    ) {
        self.remaining = remaining
        self.variant = variant
        self.side = side
        self.showsRing = showsRing
    }

    public var body: some View {
        Text(Self.text(remaining))
            .mhTypography(.label2Bold)
            .foregroundStyle(.mhLabelAlternative)
            .frame(width: side, height: side)
            .background(shape.fill(.mhBackgroundElevatedAlternative))
            .clipShape(shape)
            .background { if showsRing { ring } }
            // 라벨을 주지 않으면 "99+" 가 그대로 읽혀 무슨 수인지 알 수 없다.
            .accessibilityLabel("외 \(remaining)명")
    }

    /// 배지에 표시할 문자열. 99 이하는 그대로, 초과 시 `99+` 로 캡한다(PRD 규칙).
    public static func text(_ remaining: Int) -> String {
        remaining > 99 ? "99+" : "\(remaining)"
    }

    private var ring: some View {
        shape.fill(Color.mhBackgroundNormalNormal)
            .frame(width: side + ringWidth * 2, height: side + ringWidth * 2)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: variant.cornerRadius(size: side))
    }
}

#Preview("MHAvatarCountBadge") {
    HStack(spacing: 16) {
        MHAvatarCountBadge(remaining: 4, side: 32)
        MHAvatarCountBadge(remaining: 99, side: 32)
        MHAvatarCountBadge(remaining: 100, side: 32)   // "99+" 로 캡
        MHAvatarCountBadge(remaining: 12, side: 24)    // 방 카드 크기
    }
    .padding()
}
