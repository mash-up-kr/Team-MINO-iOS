import FlowCoordination
import SwiftUI

/// 마이 탭 flow. 아직 하위 화면이 없어 Route 는 비어 있다.
public enum ProfileRoute: Hashable {}

/// 탭 flow 는 앱 생존 내내 유지되므로 종료가 없다 — Output = Never.
@Observable
@MainActor
public final class ProfileCoordinator: Coordinator {
    public var path: [ProfileRoute] = []
    public var sheet: Never? = nil
    public var cover: Never? = nil
    public let finish = FlowFinish<Never>()

    /// 방 상세 시트 표시 여부. 시안이 탭바 없는 전체 화면이라 시트가 열려 있는 동안
    /// 앱 루트가 탭바를 감춰야 해서, 탭 화면 내부 상태가 아니라 여기(탭 flow)에 둔다.
    public var isRoomDetailPresented = false

    public init() {}
}
