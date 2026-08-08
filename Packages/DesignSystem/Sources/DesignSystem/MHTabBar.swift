import SwiftUI

/// ``MHTabBar`` 에 표시할 탭 하나의 정보.
public struct MHTabBarItem: Identifiable {
    public let id: Int
    public let icon: MHIcon
    public let label: String

    public init(id: Int, icon: MHIcon, label: String) {
        self.id = id
        self.icon = icon
        self.label = label
    }
}

// MARK: - Tab Bar

/// 하단 탭 바. Figma `Platform=iOS`(node 16215:20667).
///
/// 반투명 배경(backdrop blur) 위에 아이콘+라벨 탭 아이템을 균등 배치한다.
/// 상단에 1px 디바이더, 하단에 safe area 여백을 둔다.
///
/// - 비활성 탭: `Interaction/Inactive` (#989BA2)
/// - 활성 탭: `Label/Normal` (#171719)
/// - 라벨: `Caption 2/Medium` (SUITE 11pt)
/// - 배경: `Background/Normal/Normal` 88% + 64px backdrop blur
///
/// ```swift
/// MHTabBar(
///     items: [
///         MHTabBarItem(id: 0, icon: .homeFill, label: "홈"),
///         MHTabBarItem(id: 1, icon: .folderFill, label: "저장"),
///         MHTabBarItem(id: 2, icon: .bellFill, label: "알림"),
///         MHTabBarItem(id: 3, icon: .personFill, label: "마이페이지"),
///     ],
///     selectedID: $selected
/// )
/// ```
public struct MHTabBar: View {
    private let items: [MHTabBarItem]
    @Binding private var selectedID: Int

    public init(items: [MHTabBarItem], selectedID: Binding<Int>) {
        self.items = items
        self._selectedID = selectedID
    }

    public var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(.mhLineNormalNeutral)
                .frame(height: 1)

            HStack(spacing: 0) {
                ForEach(items) { item in
                    tabButton(item)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 2)
        }
        .padding(.bottom, 34)
        .background(.ultraThinMaterial)
        .background(Color.mhBackgroundNormalNormal.opacity(0.88))
    }

    private func tabButton(_ item: MHTabBarItem) -> some View {
        let isActive = selectedID == item.id

        return Button {
            selectedID = item.id
        } label: {
            VStack(spacing: 2) {
                Image(item.icon)
                    .resizable().scaledToFit()
                    .frame(width: 24, height: 24)

                Text(item.label)
                    .mhTypography(.caption2Medium)
            }
            .foregroundStyle(isActive ? .mhLabelNormal : .mhInteractionInactive)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

#Preview("MHTabBar") {
    struct TabBarPreview: View {
        @State private var selected = 0

        var body: some View {
            VStack {
                Spacer()
                MHTabBar(
                    items: [
                        MHTabBarItem(id: 0, icon: .homeFill, label: "홈"),
                        MHTabBarItem(id: 1, icon: .folderFill, label: "저장"),
                        MHTabBarItem(id: 2, icon: .bellFill, label: "알림"),
                        MHTabBarItem(id: 3, icon: .personCircleFill, label: "마이페이지"),
                    ],
                    selectedID: $selected
                )
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    return TabBarPreview()
}
