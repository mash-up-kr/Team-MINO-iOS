import FlowCoordination
import SwiftUI

/// 저장 탭 flow. 아직 하위 화면이 없어 Route 는 비어 있다.
public enum ArchiveRoute: Hashable {}

/// 탭 flow 는 앱 생존 내내 유지되므로 종료가 없다 — Output = Never.
@Observable
@MainActor
public final class ArchiveCoordinator: Coordinator {
    public var path: [ArchiveRoute] = []
    public var sheet: Never? = nil
    public var cover: Never? = nil
    public let finish = FlowFinish<Never>()

    public init() {}
}
