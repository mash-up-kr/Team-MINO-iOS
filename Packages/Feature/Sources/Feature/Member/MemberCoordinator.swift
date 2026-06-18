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

    public init(deps: MemberDeps, memberID: MemberID) {
        self.deps = deps
        self.memberID = memberID
    }

    // MARK: - Store Factories
    public func makeHomeStore() -> MemberHomeStore {
        let store = MemberHomeStore(
            MemberHomeState(),
            reduce: memberHomeReducer(useCase: deps.fetchMember, id: memberID)
        )
        store.observeNavigation { [weak self] in self?.handle($0) }   // 구독·Task 관리는 Store 가 담당
        return store
    }

    public func makeDetailStore(id: MemberID) -> MemberDetailStore {
        // 상세는 전환 의도가 없어(MemberDetailNav 빈 enum) observeNavigation 을 연결하지 않는다.
        MemberDetailStore(
            MemberDetailState(),
            reduce: memberDetailReducer(useCase: deps.fetchMember, id: id)
        )
    }

    // MARK: - Effect Routing (NavigationEffect → Coordinator)

    /// NavigationEffect 라우팅. 구독(observe)과 분리돼 있어 테스트에서 직접 호출해 결정적으로 검증한다.
    func handle(_ nav: MemberHomeNav) {
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
