import SwiftUI
import DesignSystem

/// 그리드 한 칸에 들어갈 것.
///
/// 캐릭터는 아직 아트가 없어 색으로만 구분하지만, 아트가 준비되면 같은 자리에 `.image` 를 넣으면 된다
/// — 그리드는 칸 내용이 색인지 이미지인지에 따라 배치를 바꾸지 않는다.
enum OnboardingGridItem {
    /// 색으로 채우는 칸. `border` 는 테두리(원형은 얇은 링, 사각형은 선택 시 채움색으로도 쓰인다).
    case color(fill: Color, border: Color)
    /// 이미지로 채우는 칸.
    case image(Image)
}

/// 칸의 시각 형태. 프로필 설정과 공동방 만들기의 피그마 디자인이 달라 형태로 갈린다.
enum OnboardingGridShape {
    /// 원형. 선택하면 바깥에 링이 생긴다 (프로필 캐릭터).
    case circle
    /// 둥근 사각. 선택하면 테두리 색으로 통짜 채우고 체크를 얹는다 (방 색상).
    case roundedSquare
}

/// 여러 칸 중 하나를 고르는 4열 그리드. 제목·배치·선택 처리를 담당하고, 칸에 무엇을 그릴지는 ``OnboardingGridItem`` 이 정한다.
struct OnboardingSelectionGrid: View {
    let title: String
    let items: [OnboardingGridItem]
    let selectedIndex: Int?
    let shape: OnboardingGridShape
    let onSelect: (Int) -> Void

    var body: some View {
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
    }

    // MARK: 원형 칸

    private func circleCell(_ item: OnboardingGridItem, isSelected: Bool) -> some View {
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

    private func roundedSquareCell(_ item: OnboardingGridItem, isSelected: Bool) -> some View {
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

private extension OnboardingGridShape {
    /// 제목과 그리드 사이 간격. 피그마가 두 화면에서 다르게 잡았다.
    var titleSpacing: CGFloat {
        switch self {
        case .circle: 16
        case .roundedSquare: 20
        }
    }
}

#Preview("원형 — 캐릭터") {
    OnboardingSelectionGrid(
        title: "프로필 이미지 선택",
        items: [Color.mhAtomicRed60, .mhAtomicOrange70, .mhAtomicLime80, .mhAtomicCyan90]
            .map { .color(fill: $0, border: .mhLineNormalAlternative) },
        selectedIndex: 1,
        shape: .circle,
        onSelect: { _ in }
    )
    .padding(20)
}

#Preview("둥근 사각 — 채움/테두리 쌍") {
    OnboardingSelectionGrid(
        title: "방 색상 선택",
        items: [
            .color(fill: .mhAtomicRed60, border: .mhAtomicRed30),
            .color(fill: .mhAtomicCyan90, border: .mhAtomicCyan50),
            .color(fill: .mhAtomicPink90, border: .mhAtomicPink60),
            .color(fill: .mhAtomicBlue65, border: .mhAtomicBlue40),
        ],
        selectedIndex: 1,
        shape: .roundedSquare,
        onSelect: { _ in }
    )
    .padding(20)
}
