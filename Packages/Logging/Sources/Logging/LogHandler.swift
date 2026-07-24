/// 로그 백엔드 추상. 구현체는 콘솔(os.Logger) 등 인프라에 의존한다.
///
/// 백엔드는 `log(_:message:metadata:file:function:line:)` 하나만 구현하면 되고,
/// 호출부가 쓰는 편의 메서드(`debug`/`info`/`notice`/`warning`/`error`)는
/// 아래 extension 이 기본 제공한다.
///
/// 이름을 `Logger` 가 아니라 `LogHandler` 로 둔 이유: `import os` 하는 파일에서
/// `Logger` 는 Apple 의 `os.Logger` 와 충돌한다. `swift-log` 도 백엔드 프로토콜을
/// `LogHandler` 로 부른다.
public protocol LogHandler: Sendable {
    func log(
        _ level: LogLevel,
        message: String,
        metadata: [String: String],
        file: String,
        function: String,
        line: UInt
    )
}

public extension LogHandler {
    func debug(
        _ message: String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        log(.debug, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    func info(
        _ message: String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        log(.info, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    func notice(
        _ message: String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        log(.notice, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    func warning(
        _ message: String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        log(.warning, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    func error(
        _ message: String,
        metadata: [String: String] = [:],
        file: String = #fileID,
        function: String = #function,
        line: UInt = #line
    ) {
        log(.error, message: message, metadata: metadata, file: file, function: function, line: line)
    }
}
