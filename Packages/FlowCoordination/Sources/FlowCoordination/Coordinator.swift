import Foundation

/// 한 flow에 속한 화면들의 전환을 책임지는 상위 객체.
///
/// 능력별로 프로토콜을 쪼개지 않고 path/sheet/cover/finish 를 한 프로토콜에 통합한다.
/// 전환 메서드(push/pop/present/dismiss)는 extension 기본 구현으로 제공하며,
/// 안 쓰는 능력(Sheet/Cover/Output)은 `Never`/`Void` 기본값으로 채운다.
///
/// 모든 Coordinator는 `@Observable @MainActor final class` 로 채택하고,
/// `init(deps:)` 로 의존성을 주입받아 자식 Coordinator 에 그대로 전달한다.
@MainActor
public protocol Coordinator: AnyObject {
    associatedtype Route: Hashable
    associatedtype Sheet: Identifiable = Never
    associatedtype Cover: Identifiable = Never
    associatedtype Output = Void

    var path: [Route] { get set }
    var sheet: Sheet? { get set }
    var cover: Cover? { get set }
    var finish: FlowFinish<Output> { get }
}

public extension Coordinator {
    func push(_ route: Route) { path.append(route) }
    func pop() { _ = path.popLast() }
    func popToRoot() { path.removeAll() }
    func present(_ sheet: Sheet) { self.sheet = sheet }
    func dismissSheet() { sheet = nil }
    func present(cover: Cover) { self.cover = cover }
    func dismissCover() { cover = nil }
}

// 안 쓰는 Sheet/Cover 는 기본값 `Never` 로 채운다.
// (`Never: Identifiable` 은 Swift 표준 라이브러리가 이미 제공한다.)
