import SwiftUI

/// 그리드 한 칸에 들어갈 것.
///
/// 색 칸과 이미지 칸 중 하나로 그린다 — 그리드는 칸 내용이 색인지 이미지인지에 따라 배치를 바꾸지 않는다.
/// > public 타입은 Sendable 을 자동 추론하지 않는다 — 스와치 배열을 전역 상수로 두는 사용처가
/// > Swift 6 동시성 검사에 걸리지 않도록 명시한다.
public enum MHSelectionGridItem: Sendable {
    /// 색으로 채우는 칸. `border` 는 테두리(원형은 얇은 링, 사각형은 선택 시 채움색으로도 쓰인다).
    case color(fill: Color, border: Color)
    /// 이미지로 채우는 칸.
    case image(Image)
}

/// 칸의 시각 형태.
public enum MHSelectionGridShape: Sendable {
    /// 원형. 선택하면 바깥에 링이 생긴다.
    case circle
    /// 둥근 사각. 선택하면 테두리 색으로 통짜 채우고 체크를 얹는다.
    case roundedSquare
}

/// 여러 칸 중 하나를 고르는 4열 그리드. 제목·배치·선택 처리를 담당하고, 칸에 무엇을 그릴지는 ``MHSelectionGridItem`` 이 정한다.
///
/// ```swift
/// MHSelectionGrid(
///     title: "방 색상 선택",
///     items: swatches,
///     selectedIndex: selected,
///     shape: .roundedSquare,
///     onSelect: { selected = $0 }
/// )
/// ```
public struct MHSelectionGrid: View {
    private let title: String
    private let items: [MHSelectionGridItem]
    private let selectedIndex: Int?
    private let shape: MHSelectionGridShape
    private let identifierPrefix: String
    private let onSelect: (Int) -> Void

    /// - Parameter identifierPrefix: 칸의 접근성 식별자 접두사(`<prefix>.cell.<index>`).
    ///   기본값을 두지 않는다 — 한 화면에 그리드가 둘 이상일 때 접두사가 겹치면 식별자가 조용히 중복되고,
    ///   빌드·테스트는 통과한 채 QA 시나리오에서야 다중 매치로 터진다.
    public init(
        title: String,
        items: [MHSelectionGridItem],
        selectedIndex: Int?,
        shape: MHSelectionGridShape,
        identifierPrefix: String,
        onSelect: @escaping (Int) -> Void
    ) {
        self.title = title
        self.items = items
        self.selectedIndex = selectedIndex
        self.shape = shape
        self.identifierPrefix = identifierPrefix
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: shape.titleSpacing) {
            Text(title)
                .mhTypography(.label1NormalBold)
                .foregroundStyle(Color.mhLabelNeutral)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Metric.spacing), count: Metric.columns),
                spacing: Metric.spacing
            ) {
                ForEach(items.indices, id: \.self) { index in
                    cell(index)
                }
            }
        }
    }

    private func cell(_ index: Int) -> some View {
        let isSelected = selectedIndex == index
        return Button {
            onSelect(index)
        } label: {
            Group {
                switch shape {
                case .circle: circleCell(items[index], isSelected: isSelected)
                case .roundedSquare: roundedSquareCell(items[index], isSelected: isSelected)
                }
            }
            .frame(width: Metric.cellSize, height: Metric.cellSize)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("\(identifierPrefix).cell.\(index)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: 원형 칸

    private func circleCell(_ item: MHSelectionGridItem, isSelected: Bool) -> some View {
        ZStack {
            switch item {
            case .color(let fill, let border):
                Circle().fill(border)
                Circle().fill(fill).padding(Metric.circleBorderWidth)
            case .image(let image):
                Circle().fill(Color.mhLineNormalAlternative)
                image.resizable().scaledToFill().clipShape(Circle()).padding(Metric.circleBorderWidth)
            }
        }
        .overlay {
            if isSelected {
                Circle()
                    .strokeBorder(Color.mhPrimaryNormal, lineWidth: Metric.selectionRingWidth)
                    .padding(-Metric.selectionRingInset)
            }
        }
    }

    // MARK: 둥근 사각 칸

    private func roundedSquareCell(_ item: MHSelectionGridItem, isSelected: Bool) -> some View {
        let box = RoundedRectangle(cornerRadius: Metric.cornerRadius)
        return ZStack {
            switch item {
            case .color(let fill, let border):
                box.fill(isSelected ? border : fill)
                if !isSelected { box.strokeBorder(border, lineWidth: Metric.squareBorderWidth) }
            case .image(let image):
                image.resizable().scaledToFill().clipShape(box)
            }
            if isSelected {
                Image(MHIcon.checkThick)
                    .resizable()
                    .frame(width: Metric.checkSize, height: Metric.checkSize)
                    .foregroundStyle(Color.mhStaticWhite)
            }
        }
        .mhShadow(.medium, cornerRadius: Metric.cornerRadius)
    }

    private enum Metric {
        static let columns = 4
        static let spacing: CGFloat = 10
        static let cellSize: CGFloat = 70
        static let cornerRadius: CGFloat = 20
        static let circleBorderWidth: CGFloat = 1.25
        static let squareBorderWidth: CGFloat = 3
        static let selectionRingWidth: CGFloat = 2
        static let selectionRingInset: CGFloat = 3
        static let checkSize: CGFloat = 28
    }
}

private extension MHSelectionGridShape {
    /// 제목과 그리드 사이 간격. 피그마가 두 형태에서 다르게 잡았다.
    var titleSpacing: CGFloat {
        switch self {
        case .circle: 16
        case .roundedSquare: 20
        }
    }
}

#Preview("원형 — 캐릭터") {
    MHSelectionGrid(
        title: "프로필 이미지 선택",
        items: [Color.mhRed60, .mhOrange70, .mhLime80, .mhCyan90]
            .map { .color(fill: $0, border: .mhLineNormalAlternative) },
        selectedIndex: 1,
        shape: .circle,
        identifierPrefix: "Preview.character",
        onSelect: { _ in }
    )
    .padding(20)
}

#Preview("둥근 사각 — 채움/테두리 쌍") {
    MHSelectionGrid(
        title: "방 색상 선택",
        items: [
            .color(fill: .mhRed60, border: .mhRed30),
            .color(fill: .mhCyan90, border: .mhCyan50),
            .color(fill: .mhPink90, border: .mhPink60),
            .color(fill: .mhBlue65, border: .mhBlue40),
        ],
        selectedIndex: 1,
        shape: .roundedSquare,
        identifierPrefix: "Preview.color",
        onSelect: { _ in }
    )
    .padding(20)
}
