import Domain
import FlowCoordination
import MVI
import SwiftUI

public enum MemberRoute: Hashable {
    case detail(MemberID)
}

public enum MemberSheet: Identifiable {
    case edit
    public var id: String { "edit" }
}

/// Member flow 의 부모 Coordinator.
/// NavigationEffect(화면 내 push) 와 sheet 자식 flow(FlowFinish) 두 출력 채널을 모두 다룬다.
@Observable
@MainActor
public final class MemberCoordinator: Coordinator {
    // MARK: - Capabilities (Coordinator 프로토콜 요구)
    public var path: [MemberRoute] = []
    public var sheet: MemberSheet? = nil
    public var cover: Never? = nil
    public let finish = FlowFinish<Void>()       // 루트라 미사용(죽은 프로퍼티)

    // MARK: - Dependencies / Lifecycle  (deps 주입)
    private let deps: MemberDeps
    private let memberID: MemberID

    /// sheet 자식 Coordinator 를 strong 보유(@Observable 추적 + 수명 관리).
    public var editChild: MemberEditCoordinator?
    /// flowRoot onFinish 결과 반영 시범용.
    public var lastEditResult: EditResult?

    @ObservationIgnored nonisolated(unsafe) private var effectTasks: [Task<Void, Never>] = []

    public init(deps: MemberDeps, memberID: MemberID) {
        self.deps = deps
        self.memberID = memberID
    }

    deinit { effectTasks.forEach { $0.cancel() } }

    // MARK: - Store Factories
    public func makeMemberStore() -> MemberStore {
        makeStore(for: memberID)
    }

    public func makeDetailStore(id: MemberID) -> MemberStore {
        makeStore(for: id)
    }

    private func makeStore(for id: MemberID) -> MemberStore {
        let store = MemberStore(
            MemberState(),
            reduce: memberReducer(useCase: deps.fetchMember, id: id)
        )
        observe(store)
        return store
    }

    // MARK: - Effect Routing (NavigationEffect → Coordinator)
    private func observe(_ store: MemberStore) {
        let task = Task { @MainActor [weak store, weak self] in
            guard let store else { return }
            for await nav in store.navigationEffects { self?.handle(nav) }
        }
        effectTasks.append(task)
    }

    private func handle(_ nav: MemberNav) {
        switch nav {
        case .goToDetail(let id):
            push(.detail(id))
        case .presentEdit:
            editChild = MemberEditCoordinator(deps: deps)   // 자식에 같은 deps 전달
            present(.edit)
        }
    }

    // MARK: - Flow Control
    /// 자식 편집 flow 가 끝났을 때 부모가 한 줄로 위임받는 자리.
    public func editDidFinish(_ result: EditResult) {
        lastEditResult = result
        editChild = nil
    }
}
