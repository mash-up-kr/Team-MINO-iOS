import DesignSystem
import FlowCoordination
import SwiftUI

/// 마이 탭 진입 View. 이번 브랜치에서 추가한 합성 컴포넌트를 확인할 수 있다.
public struct ProfileTabView: View {
    private let coordinator: ProfileCoordinator
    @State private var selected = 0

    public init(coordinator: ProfileCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            VStack(spacing: 0) {
                Picker("컴포넌트", selection: $selected) {
                    Text("Invitation").tag(0)
                    Text("Card").tag(1)
                    Text("Thumbnail").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    Group {
                        switch selected {
                        case 0:  invitationPage
                        case 1:  cardPage
                        default: thumbnailPage
                        }
                    }
                    .padding()
                }
            }
            .accessibilityIdentifier("ProfileTab.title")
        }
    }

    // MARK: - Pages

    private var invitationPage: some View {
        MHInvitation(
            thumbnailColor: .pink,
            title: "5월의 약속 : 우리끼리",
            description: "우리 모임 장소 픽업 공간.",
            members: [nil, nil, nil],
            placeCount: 1200
        )
    }

    private var cardPage: some View {
        VStack(spacing: 16) {
            MHInvitationCard(
                thumbnailColor: .pink,
                title: "5월의 약속 : 우리끼리",
                description: "우리 모임 장소 픽업 공간.",
                members: [nil, nil, nil],
                placeCount: 1200
            )
            .frame(width: 260)

            MHInvitationCard(
                thumbnailColor: .violet,
                title: "5월의 약속 : 우리끼리",
                description: "우리 모임 장소 픽업 공간.",
                members: [nil, nil, nil, nil, nil, nil, nil],
                placeCount: 5
            )
            .frame(width: 200)
        }
    }

    private var thumbnailPage: some View {
        VStack(spacing: 24) {
            Text("unselect").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(70), spacing: 10), count: 4), spacing: 10) {
                ForEach(MHRoomThumbnailColor.allCases, id: \.self) { color in
                    MHRoomThumbnail(color: color, size: 70)
                }
            }

            Text("select").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(70), spacing: 10), count: 4), spacing: 10) {
                ForEach(MHRoomThumbnailColor.allCases.filter { $0 != .normal }, id: \.self) { color in
                    MHRoomThumbnail(color: color, isSelected: true, size: 70)
                }
            }
        }
    }
}

#Preview {
    ProfileTabView(coordinator: ProfileCoordinator())
}
