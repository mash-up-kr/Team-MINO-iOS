import SwiftUI

/// Member flow 의 진입 View. NavigationStack(path) + sheet 를 Coordinator 상태에 바인딩한다.
public struct MemberHomeView: View {
    private let coordinator: MemberCoordinator
    @State private var store: MemberHomeStore?

    public init(coordinator: MemberCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) {
            homeContent
                .navigationDestination(for: MemberRoute.self) { route in
                    switch route {
                    case .detail(let id):
                        MemberDetailView(coordinator: coordinator, id: id)
                    }
                }
        }
        .sheet(item: $coordinator.sheet, onDismiss: { coordinator.editDismissed() }) { sheet in
            switch sheet {
            case .edit:
                if let child = coordinator.editChild {
                    MemberEditFormView(coordinator: child)
                        .flowRoot(child) { [weak coordinator] result in
                            coordinator?.editDidFinish(result)   // [weak] 로 부모↔자식 retain cycle 차단
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var homeContent: some View {
        if let store {
            MemberHomeContentView(store: store)
        } else {
            ProgressView()
                .task { store = coordinator.makeHomeStore() }
        }
    }
}

/// 로딩/표시 + 화면 전환 트리거. store 의 상태를 읽어 그린다.
struct MemberHomeContentView: View {
    let store: MemberHomeStore

    var body: some View {
        VStack(spacing: 16) {
            if store.state.isLoading {
                ProgressView()
                    .accessibilityIdentifier("MemberHome.state.loading")
            } else if let member = store.state.member {
                Text("안녕하세요, \(member.name)님")
                    .font(.title2)
                    .accessibilityIdentifier("MemberHome.greetingText")
                Button("상세 보기") { store.send(.tapDetail) }
                    .accessibilityIdentifier("MemberHome.detailButton")
                Button("편집") { store.send(.tapEdit) }
                    .accessibilityIdentifier("MemberHome.editButton")
            } else if let message = store.state.errorMessage {
                Text("불러오기 실패: \(message)")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("MemberHome.state.error")
            }
        }
        .padding()
        .navigationTitle("Member")
        .task { store.send(.load) }
    }
}
