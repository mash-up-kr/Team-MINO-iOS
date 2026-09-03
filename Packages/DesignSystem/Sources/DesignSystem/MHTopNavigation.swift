import SwiftUI

/// 화면 상단 내비게이션. Figma `Top Navigation/Top Navigation`.
///
/// 타이틀은 가운데 고정이고 뒤로가기·건너뛰기·닫기는 좌우 끝에 얹힌다 — 타이틀이 길어져도 버튼을 밀지 않도록
/// 겹쳐 배치한다. 네 요소 모두 선택이라, 필요한 것만 넘기면 된다(타이틀만 쓰거나 버튼만 쓸 수 있다).
///
/// > 시스템 내비바(`.navigationTitle`)를 쓰지 않는 이유: Figma 타이틀이 SUITE 인데 시스템 내비바는
/// > 시스템 폰트로 그린다. 이 컴포넌트를 쓰는 화면은 `.toolbar(.hidden, for: .navigationBar)` 를 함께 건다.
///
/// > 우측은 건너뛰기와 닫기가 같은 자리를 쓴다. 둘이 함께 오는 시안은 없지만, 둘 다 넘기면
/// > 건너뛰기 → 닫기 순으로 나란히 그린다.
///
/// ```swift
/// MHTopNavigation(title: "공동방 만들기", onBack: { dismiss() }, onSkip: { skip() })
/// MHTopNavigation(title: "프로필 설정")                        // 타이틀만
/// MHTopNavigation(onBack: { dismiss() }, onSkip: { skip() })  // 버튼만
/// MHTopNavigation(onClose: { close() })                       // 닫기(X)만 — 온보딩 친구초대
/// ```
public struct MHTopNavigation: View {
    private let title: String?
    private let onBack: (() -> Void)?
    private let onSkip: (() -> Void)?
    private let onClose: (() -> Void)?

    public init(
        title: String? = nil,
        onBack: (() -> Void)? = nil,
        onSkip: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.title = title
        self.onBack = onBack
        self.onSkip = onSkip
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            if let title {
                Text(title)
                    .mhTypography(.headline2Bold)
                    .foregroundStyle(Color.mhLabelStrong)
                    .lineLimit(1)
                    .accessibilityIdentifier("MHTopNavigation.title")
            }
            HStack(spacing: 16) {
                if let onBack {
                    Button(action: onBack) {
                        Image(MHIcon.chevronLeft)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(Color.mhLabelNormal)
                    }
                    .accessibilityLabel("뒤로")
                    .accessibilityIdentifier("MHTopNavigation.back")
                }
                Spacer(minLength: 0)
                if let onSkip {
                    // MHTextButton 은 Body1Bold(16) 고정이라 Figma 스펙(Label1Medium 14)과 달라 직접 조립한다.
                    Button(action: onSkip) {
                        Text("건너뛰기")
                            .mhTypography(.label1NormalMedium)
                            .foregroundStyle(Color.mhLabelNormal)
                    }
                    .accessibilityIdentifier("MHTopNavigation.skip")
                }
                if let onClose {
                    Button(action: onClose) {
                        Image(MHIcon.close)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(Color.mhLabelNormal)
                    }
                    .accessibilityLabel("닫기")
                    .accessibilityIdentifier("MHTopNavigation.close")
                }
            }
        }
        .frame(minHeight: 24)                 // 버튼이 없는 화면에서도 아이콘(24pt) 기준 높이를 유지
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

#Preview("타이틀 + 뒤로 + 건너뛰기") {
    MHTopNavigation(title: "공동방 만들기", onBack: {}, onSkip: {})
}

#Preview("타이틀만") {
    MHTopNavigation(title: "프로필 설정")
}

#Preview("뒤로 + 건너뛰기") {
    MHTopNavigation(onBack: {}, onSkip: {})
}

#Preview("닫기만") {
    MHTopNavigation(onClose: {})
}
