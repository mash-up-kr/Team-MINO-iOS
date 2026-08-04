import SwiftUI

// MARK: - Comment

/// 작성자(아바타 + 이름)와 코멘트 본문을 보여주는 표시형 컴포넌트. Figma `comment`(node 15852:88585).
///
/// 상단에 32pt 아바타와 이름, 아래에 본문을 둔다. 본문은 `maxBodyHeight`(기본 140pt)를 넘으면 말줄임 없이
/// 그대로 **잘린다**(Figma overflow-clip). Figma 의 normal/half/full 상태는 본문 길이 차이일 뿐 한 컴포넌트다.
///
/// > 본문 색은 Figma 가 raw `#000000` 을 쓰지만, 라이트에서 사실상 동일하고 다크 대응을 위해 `Label/Normal`
/// > 토큰으로 매핑했다.
///
/// ```swift
/// MHComment(avatar: Image("me"), name: "이름", comment: "친구가 남긴 코멘트입니다.")
/// MHComment(avatar: nil, name: "이름", comment: longText) { openProfile() }   // 아바타 탭
/// ```
public struct MHComment: View {
    private let avatar: Image?
    private let name: String
    private let comment: String
    private let maxBodyHeight: CGFloat
    private let onAvatarTap: (() -> Void)?

    public init(
        avatar: Image?,
        name: String,
        comment: String,
        maxBodyHeight: CGFloat = 140,
        onAvatarTap: (() -> Void)? = nil
    ) {
        self.avatar = avatar
        self.name = name
        self.comment = comment
        self.maxBodyHeight = maxBodyHeight
        self.onAvatarTap = onAvatarTap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                MHAvatar(avatar, size: 32, action: onAvatarTap)
                Text(name)
                    .mhTypography(.label1NormalMedium)
                    .foregroundStyle(.mhLabelAlternative)
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
