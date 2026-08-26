import Foundation

/// 어떤 유도 UI 를 "나중에" 로 미뤄 두는 스위치. 마지막으로 미룬 시각만 남기고, 유예 기간이
/// 지나면 저절로 풀린다.
///
/// 영구 차단이 아니라 **기간 만료**라는 점이 요점이다 — 되돌릴 수단 없이 꺼지는 플래그는
/// 사용자도 개발자도 손댈 수 없는 상태를 만든다.
///
/// ```swift
/// let snooze = SnoozeSwitch(key: "roomCreationPrompt", period: .days(14))
/// if !snooze.isSnoozed { present() }
/// snooze.snooze()                      // "나중에 만들래요"
/// ```
///
/// > 저장소는 `UserDefaults` 다. 기기 하나에만 남고 앱을 지우면 함께 사라진다 — 서버가 알아야 하는
/// > 상태가 되면 그때 Domain 으로 올린다.
// `UserDefaults` 는 Sendable 로 선언돼 있지 않지만 Apple 문서상 스레드 안전하다(내부 동기화).
// 나머지 저장 프로퍼티는 값 타입·@Sendable 클로저라 unchecked 로 막는 범위가 그 하나뿐이다.
public struct SnoozeSwitch: @unchecked Sendable {
    private let key: String
    private let period: TimeInterval
    private let defaults: UserDefaults
    private let now: @Sendable () -> Date

    /// - Parameters:
    ///   - key: `UserDefaults` 키. 유도 UI 마다 다르게 준다.
    ///   - period: 유예 기간. 이 시간이 지나면 다시 노출된다.
    ///   - now: 현재 시각. 테스트가 시간을 고정할 수 있도록 주입받는다.
    public init(
        key: String,
        period: TimeInterval,
        defaults: UserDefaults = .standard,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.key = key
        self.period = period
        self.defaults = defaults
        self.now = now
    }

    /// 아직 미뤄 둔 상태인가. 한 번도 미룬 적이 없거나 유예 기간이 지났으면 `false`.
    public var isSnoozed: Bool {
        guard let snoozedAt = defaults.object(forKey: key) as? Date else { return false }
        // 기기 시계를 과거로 돌리면 snoozedAt 이 미래가 된다. 그때도 만료로 보지 않고 미룬 상태를
        // 유지한다(음수 경과) — 시계를 돌려 유도 UI 를 되살리는 쪽이 더 이상하다.
        return now().timeIntervalSince(snoozedAt) < period
    }

    /// 지금부터 유예 기간 동안 미룬다.
    public func snooze() {
        defaults.set(now(), forKey: key)
    }
}

public extension TimeInterval {
    /// 일 단위 유예 기간.
    static func days(_ count: Int) -> TimeInterval { TimeInterval(count) * 24 * 60 * 60 }
}
