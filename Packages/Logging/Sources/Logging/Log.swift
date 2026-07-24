import os

/// 앱 전역 로그 진입점. 어디서든 `Log.debug("...")` 처럼 호출한다.
///
/// 실제 백엔드는 앱 시작 시 `Log.bootstrap(_:)` 으로 1회 주입한다.
/// 미주입 상태에서도 안전하도록 기본 백엔드는 `OSLogger()`.
///
/// 백엔드 참조는 `OSAllocatedUnfairLock` 으로 보호해 Swift 6 동시성 안전을 만족한다.
/// 잠금은 백엔드 참조 획득까지만 잡고, 실제 로깅은 잠금 밖에서 수행한다.
public enum Log {
    // bootstrap 전에 찍히는 로그도 AppDelegate 와 같은 레벨 정책을 따르게 한다.
    // (기본값이 .debug 면 릴리즈에서 bootstrap 이전 로그가 전부 노출되는 구멍이 생김)
    #if DEBUG
    private static let defaultLevel: LogLevel = .debug
    #else
    private static let defaultLevel: LogLevel = .warning
    #endif

    private static let backend = OSAllocatedUnfairLock<any LogHandler>(initialState: OSLogger(minimumLevel: defaultLevel))

    /// 백엔드 교체. 앱 시작 시 1회 호출한다.
    public static func bootstrap(_ logger: any LogHandler) {
        backend.withLock { $0 = logger }
    }

    public static func debug(
        _ message: String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        current.debug(message, metadata: metadata, file: file, function: function, line: line)
    }

    public static func info(
        _ message: String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        current.info(message, metadata: metadata, file: file, function: function, line: line)
    }

    public static func notice(
        _ message: String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        current.notice(message, metadata: metadata, file: file, function: function, line: line)
    }

    public static func warning(
        _ message: String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        current.warning(message, metadata: metadata, file: file, function: function, line: line)
    }

    public static func error(
        _ message: String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        current.error(message, metadata: metadata, file: file, function: function, line: line)
    }

    private static var current: any LogHandler {
        backend.withLock { $0 }
    }
}
