/// 아무 것도 하지 않는 로그 백엔드. 테스트·프리뷰에서 로그를 삼킬 때 쓴다.
public struct NoopLogger: LogHandler {
    public init() {}

    public func log(
        _ level: LogLevel,
        message: String,
        metadata: [String: String],
        file: String,
        function: String,
        line: UInt
    ) {}
}
