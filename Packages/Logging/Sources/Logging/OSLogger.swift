import Foundation
import os

/// os.Logger(Apple 통합 로깅) 기반 콘솔 로그 백엔드.
///
/// - `minimumLevel` 미만 로그는 버린다. 릴리즈에서 `debug`/`info` 를 억제하는 용도.
/// - 메시지·메타데이터는 `.public` 으로 남긴다. 디버그 로거이므로 릴리즈 기기 로그에서도
///   값이 보여야 쓸모가 있다. 대신 **민감값(토큰·비밀번호·이메일 등)은 로그에 넣지 않는다**(규약).
public struct OSLogger: LogHandler {
    private let logger: os.Logger
    private let minimumLevel: LogLevel

    public init(
        subsystem: String = Bundle.main.bundleIdentifier ?? "app",
        category: String = "app",
        minimumLevel: LogLevel = .debug
    ) {
        self.logger = os.Logger(subsystem: subsystem, category: category)
        self.minimumLevel = minimumLevel
    }

    public func log(
        _ level: LogLevel,
        message: String,
        metadata: [String: String],
        file: String,
        function: String,
        line: UInt
    ) {
        guard level >= minimumLevel else { return }

        let meta = Self.formatMetadata(metadata)
        let location = "(\(file):\(line))"

        logger.log(
            level: level.osLogType,
            "\(message, privacy: .public)\(meta, privacy: .public) \(location, privacy: .public)"
        )
    }

    /// 메타데이터를 결정적 문자열로 조립한다. 키로 정렬하고, 비어 있으면 빈 문자열.
    /// os.Logger 출력은 관측할 수 없으므로, 조립 규칙(정렬·구분자·빈 처리)은 이 순수 함수로 테스트한다.
    static func formatMetadata(_ metadata: [String: String]) -> String {
        metadata.isEmpty
            ? ""
            : " " + metadata.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
    }
}

private extension LogLevel {
    /// os 통합 로깅 타입으로 매핑한다. os 레벨은 5종(.debug/.info/.default/.error/.fault)뿐이고
    /// Apple 가이드상 `.error` 는 "실행 중 에러", `.fault` 는 "프로그램 버그"다.
    /// - os 에 `warning` 대응이 없어 `notice`·`warning` 을 함께 `.default`("주목할 일, 에러 아님")로 둔다.
    /// - `error → .error` 로 매핑한다. `.fault` 는 일상 에러엔 과하므로 향후 critical 레벨용으로 남겨둔다.
    var osLogType: OSLogType {
        switch self {
        case .debug: .debug
        case .info: .info
        case .notice: .default
        case .warning: .default
        case .error: .error
        }
    }
}
