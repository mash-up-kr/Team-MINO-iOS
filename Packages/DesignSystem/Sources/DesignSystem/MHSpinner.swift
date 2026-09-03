import SwiftUI

/// 진행률을 모르는 대기를 나타내는 원형 인디케이터. Figma `Circular/Circular`.
///
/// 시안은 3/4 원호에 둥근 끝을 두고 시계 방향으로 돈다. 선 굵기는 시안 28pt 에서 3 인 비율을 따른다.
///
/// > `MHButton(isLoading:)` 안의 스피너는 별개다 — 그쪽은 버튼 라벨 색을 물려받아야 해서
/// > 색을 받지 않는 내부 구현(`MHButtonSpinner`)을 쓴다.
///
/// ```swift
/// MHSpinner()                                   // 28pt, 옅은 회색 (기본)
/// MHSpinner(size: 20, color: .mhStaticWhite)    // 어두운 배경 위
/// ```
public struct MHSpinner: View {
    private let size: CGFloat
    private let color: Color

    @State private var spin = false

    public init(size: CGFloat = 28, color: Color = .mhLineSolidNormal) {
        self.size = size
        self.color = color
    }

    public var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(color, style: StrokeStyle(lineWidth: max(1.5, size * 3 / 28), lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: spin)
            .onAppear { spin = true }
            .accessibilityHidden(true)
    }
}

#Preview("MHSpinner") {
    VStack(spacing: 24) {
        MHSpinner()
        MHSpinner(size: 20)
        MHSpinner(size: 40)
    }
    .padding(40)
}
