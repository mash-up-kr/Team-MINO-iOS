import DesignSystem
import FlowCoordination
import SwiftUI

/// 홈 탭 진입 View. 실제 화면이 붙기 전까지 디자인 시스템 프리뷰를 표시한다.
public struct HomeTabView: View {
    private let coordinator: HomeCoordinator
    @State private var selected = 0

    public init(coordinator: HomeCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            VStack(spacing: 0) {
                Picker("컴포넌트", selection: $selected) {
                    Text("Invitation").tag(0)
                    Text("InvitationCard").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    Group {
                        switch selected {
                        case 0:
                            MHInvitation(
                                thumbnailColor: .pink,
                                title: "5월의 약속 : 우리끼리",
                                description: "우리 모임 장소 픽업 공간.",
                                members: [nil, nil, nil],
                                placeCount: 1200
                            )
                        default:
                            MHInvitationCard(
                                thumbnailColor: .violet,
                                title: "5월의 약속 : 우리끼리",
                                description: "우리 모임 장소 픽업 공간.",
                                members: [nil, nil, nil],
                                placeCount: 5
                            )
                            .frame(width: 260)
                        }
                    }
                    .padding()
                }
            }
            .accessibilityIdentifier("HomeTab.title")
        }
    }
}
