import Domain
import FlowCoordination
import MVI
import SwiftUI

public enum MemberRoute: Hashable {
    case detail(MemberID)
}

public enum MemberSheet: String, Identifiable {
    case edit
    public var id: String { rawValue }   // 케이스마다 rawValue 가 자동으로 달라져 id 갱신 누락을 막는다
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

    // store 별 NavigationEffect 구독. store 가 해제되면 구독이 끝나며 자기 자신을 제거한다.
    // 쓰기는 @MainActor, 읽기는 nonisolated deinit. @MainActor 객체(소유자도 @MainActor)라
    // MainActor 에서 해제된다는 가정 위에서 race-free 이다(보장은 아님; Swift 6.1 isolated deinit 으로 정리 가능).
    @ObservationIgnored nonisolated(unsafe) private var effectTasks: [UUID: Task<Void, Never>] = [:]

    public init(deps: MemberDeps, memberID: MemberID) {
        self.deps = deps
        self.memberID = memberID
    }

    deinit { effectTasks.values.forEach { $0.cancel() } }

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
        let id = UUID()
        effectTasks[id] = Task { @MainActor [weak store, weak self] in
            defer { self?.effectTasks[id] = nil }   // 모든 종료 경로(early-return 포함)에서 정리
            guard let store else { return }
            for await nav in store.navigationEffects { self?.handle(nav) }
        }
    }

    /// NavigationEffect 라우팅. 구독(observe)과 분리돼 있어 테스트에서 직접 호출해 결정적으로 검증한다.
    func handle(_ nav: MemberNav) {
        switch nav {
        case .goToDetail(let id):
            push(.detail(id))
        case .presentEdit:
            editChild = MemberEditCoordinator()   // 자식은 자기 의존이 없어 deps 불필요
            present(.edit)
        }
    }

    // MARK: - Flow Control
    /// 자식 편집 flow 가 끝났을 때(저장/취소) 부모가 한 줄로 위임받는 자리.
    public func editDidFinish(_ result: EditResult) {
        lastEditResult = result
        editChild = nil
    }

    /// 시트가 닫힐 때(스와이프 등 finish 미발사 포함) 호출. finish 로 이미 정리됐으면 no-op.
    public func editDismissed() {
        guard editChild != nil else { return }   // 저장/취소로 이미 editChild = nil 된 경우
        editChild = nil                          // 스와이프 dismiss 를 정리(취소로 정규화)
    }
}
