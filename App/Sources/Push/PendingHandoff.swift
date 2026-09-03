import Foundation

/// 소비자가 **늦게 꽂히는** 채널. 꽂히기 전에 도착한 값을 들고 있다가 그 순간 흘려보낸다.
///
/// 푸시 delegate 두 종류가 같은 처지다 — 둘 다 프로세스 시작에 붙어야 하는데(그래야 콜드런치에서
/// 오는 첫 콜백을 받는다) 소비자인 `AppCoordinator` 는 SwiftUI 쪽에서 나중에 만들어진다.
/// 그 틈에 온 값을 버리면 **누른 푸시가 통째로 사라지거나 첫 토큰을 놓친다.**
///
/// 최신 하나만 남긴다 — 토큰도 탭도 마지막 것이 맞다.
@MainActor
final class PendingHandoff<Value> {
    var onValue: ((Value) -> Void)? {
        didSet {
            guard let value = pending else { return }
            pending = nil
            onValue?(value)
        }
    }

    private var pending: Value?

    func deliver(_ value: Value) {
        if let onValue {
            onValue(value)
        } else {
            pending = value
        }
    }
}
