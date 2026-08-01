import SwiftUI

// MARK: - Avatar

/// 아바타 종류. `person`(원형) / `company`·`academy`(둥근 사각, radius = 크기×0.25). Figma `variant`.
///
/// person 은 사람용(원), company·academy 는 기관용(둥근 사각)이다. 셋 다 이미지가 없으면
/// 기본 placeholder 를 보여준다(현재 person=사람 아이콘). Figma 는 company=건물·academy=학사모
/// placeholder 아이콘을 쓰지만, 그 두 일러스트는 아이콘 세트에 없어(에셋 대기) 지금은 빈 배경으로 둔다.
public enum MHAvatarVariant: Sendable { case person, company, academy }

extension MHAvatarVariant {
    // 모서리: person=원(크기/2), company·academy=크기×0.25(홀수면 짝수로 올림, Figma 규칙).
    func cornerRadius(size: CGFloat) -> CGFloat {
        switch self {
        case .person:            return size / 2
        case .company, .academy: return (size * 0.25 / 2).rounded(.up) * 2
        }
    }
}

/// 사람/기관을 나타내는 원형(또는 둥근 사각) 아바타. Figma `Avatar/Avatar`.
///
/// `size`(24/32/40/48/56 기본 + 커스텀)의 정사각에 이미지를 꽉 채워(fill) 자르고, 흰 배경 + 얇은 테두리를
/// 두른다. 우상단 코너에는 `badge` 슬롯(알림 배지 등)을 얹을 수 있다. `action` 을 주면 눌러지는 아바타가 된다.
///
/// 테두리는 `borderColor`(기본 `Line/Normal/Alternative`)·`borderWidth`(기본 1)로 오버라이드할 수 있다 —
/// Figma customize 축(`borderColor`·`borderWeight`·`size`).
///
/// > 커스텀 크기의 모서리 둥글기는 크기×0.25(홀수면 짝수로 올림) — Figma 규칙.
///
/// ```swift
/// MHAvatar(Image("profile"), size: 40)                       // 원형 이미지
/// MHAvatar(nil, variant: .company, size: 48)                 // 기관(둥근 사각) placeholder
/// MHAvatar(Image("me"), size: 56) { MHContentBadge("N", color: .mhStatusNegative) }  // 배지
/// MHAvatar(Image("u"), size: 32) { } action: { open() }      // 눌러지는 아바타
/// MHAvatar(Image("p"), size: 40, borderColor: .mhPrimaryNormal, borderWidth: 2)      // 테두리 커스텀
/// ```
public struct MHAvatar<Badge: View>: View {
    private let image: Image?
    private let variant: MHAvatarVariant
    private let size: CGFloat
    private let borderColor: Color
    private let borderWidth: CGFloat
    private let action: (() -> Void)?
    private let badge: Badge

    // badge 를 action 보다 앞에 둔다 — 후행 클로저(전방 스캔)가 첫 함수형 파라미터에 붙으므로
    // `MHAvatar(img) { 배지 }` 가 badge 에 바인딩되게 하려면 badge 가 앞이어야 한다.
    public init(
        _ image: Image?,
        variant: MHAvatarVariant = .person,
        size: CGFloat = 40,
        borderColor: Color = .mhLineNormalAlternative,
        borderWidth: CGFloat = 1,
        @ViewBuilder badge: () -> Badge = { EmptyView() },
        action: (() -> Void)? = nil
    ) {
        self.image = image
        self.variant = variant
        self.size = size
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.badge = badge()
        self.action = action
    }

    private var cornerRadius: CGFloat { variant.cornerRadius(size: size) }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        avatar(shape)
            .overlay(alignment: .topTrailing) { cornerBadge }   // 배지는 코너 중심에(클립 밖)
    }

    // 아바타 본체(이미지/placeholder + 배경 + 테두리). action 이 있으면 눌러지게.
    @ViewBuilder private func avatar(_ shape: RoundedRectangle) -> some View {
        let content = ZStack {
            if let image {
                image.resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        // Figma: 이미지=Static/White(중립 흰 배경), placeholder=Background/Normal/Normal(테마 적응 → 다크모드서 어두운 원)
        .background(image != nil ? Color.mhStaticWhite : Color.mhBackgroundNormalNormal)
        .clipShape(shape)
        .overlay { shape.strokeBorder(borderColor, lineWidth: borderWidth) }

        if let action {
            Button(action: action) { content }
                .buttonStyle(MHAvatarStyle(size: size, cornerRadius: cornerRadius))
        } else {
            content
        }
    }

    // 이미지 없을 때 기본 표시. person=사람 아이콘(회색). company(건물)·academy(학사모)는 Figma placeholder
    // 아이콘이 아이콘 세트에 없어(에셋 대기) 빈 배경 — 에셋 확보 시 person 과 대칭으로 추가.
    @ViewBuilder private var placeholder: some View {
        if variant == .person {
            Image(MHIcon.personFill)
                .resizable().scaledToFit()
                .frame(width: size * 0.5, height: size * 0.5)   // Figma placeholder ~50%
                .foregroundStyle(.mhLabelAssistive)
        }
    }

    // 우상단 코너 중심에 배지 정렬(코너 밖으로 살짝 넘침 — Figma push badge 위치).
    @ViewBuilder private var cornerBadge: some View {
        badge
            .alignmentGuide(.trailing) { $0[HorizontalAlignment.center] }
            .alignmentGuide(.top) { $0[VerticalAlignment.center] }
    }
}

// MARK: - ButtonStyle (press 오버레이)

// 눌렀을 때: Figma 인터랙션 = 아바타보다 8px 큰 halo 를 뒤에 깔아(Label/Normal 0.09) 둘레에
// 옅은 링이 뜬다(`inset-[-8px]`). 아바타 본체가 중앙을 덮어 8px 링만 보인다. shape 안쪽 tint 가 아님.
struct MHAvatarStyle: ButtonStyle {
    let size: CGFloat
    let cornerRadius: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: cornerRadius + 8)  // 아바타 shape 와 동심(반경 +8)
                        .fill(Color.mhLabelNormal.opacity(0.09))
                        .frame(width: size + 16, height: size + 16)   // 상하좌우 8px 확장(레이아웃엔 영향 없음)
                }
            }
    }
}
