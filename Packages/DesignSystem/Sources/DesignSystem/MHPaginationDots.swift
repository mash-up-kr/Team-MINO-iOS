import SwiftUI

/// 캐러셀의 현재 페이지를 점으로 표시한다. Figma `Pagination/Dots`.
///
/// 표시 전용이다 — 탭으로 페이지를 옮기지 않는다.
///
/// ```swift
/// MHPaginationDots(count: 5, current: pageIndex)
/// ```
public struct MHPaginationDots: View {
    private static let dotSize: CGFloat = 10
    private static let inactiveOpacity: Double = 0.16

    private let count: Int
    private let current: Int

    public init(count: Int, current: Int) {
        self.count = count
        self.current = current
    }

    public var body: some View {
        HStack(spacing: Self.dotSize) {
            ForEach(0..<max(0, count), id: \.self) { index in
                Circle()
                    .fill(Color.mhLabelNormal)
                    .opacity(index == current ? 1 : Self.inactiveOpacity)
                    .frame(width: Self.dotSize, height: Self.dotSize)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count)페이지 중 \(current + 1)페이지")
        .accessibilityIdentifier("MHPaginationDots")
    }
}

#Preview {
    VStack(spacing: 24) {
        MHPaginationDots(count: 5, current: 0)
        MHPaginationDots(count: 5, current: 2)
        MHPaginationDots(count: 5, current: 4)
    }
}
