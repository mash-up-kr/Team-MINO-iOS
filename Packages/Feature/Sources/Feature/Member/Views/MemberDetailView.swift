import SwiftUI
import Domain

/// push 로 진입하는 상세 화면. 자신의 Store 를 직접 보유(화면 단위 독립 Store).
struct MemberDetailView: View {
    @Environment(MemberCoordinator.self) private var coordinator
    let id: MemberID
    @State private var store: MemberStore?

    var body: some View {
        Group {
            if let store {
                VStack(spacing: 12) {
                    if store.state.isLoading {
                        ProgressView()
                    } else if let member = store.state.member {
                        Text(member.name).font(.title)
                        if let email = member.email {
                            Text(email).foregroundStyle(.secondary)
                        }
                        Text("ID: \(member.id.value)").font(.footnote)
                    }
                }
                .padding()
                .task { store.send(.load) }
            } else {
                ProgressView()
                    .task { store = coordinator.makeDetailStore(id: id) }
            }
        }
        .navigationTitle("상세")
    }
}
