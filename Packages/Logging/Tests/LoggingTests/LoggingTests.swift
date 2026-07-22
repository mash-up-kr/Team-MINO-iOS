import XCTest
@testable import Logging

final class LoggingTests: XCTestCase {

    // MARK: - LogLevel

    func test_logLevel_ordering() {
        XCTAssertLessThan(LogLevel.debug, LogLevel.info)
        XCTAssertLessThan(LogLevel.info, LogLevel.notice)
        XCTAssertLessThan(LogLevel.notice, LogLevel.warning)
        XCTAssertLessThan(LogLevel.warning, LogLevel.error)
    }

    // MARK: - 편의 메서드 → log 위임

    func test_convenienceMethods_forwardCorrectLevel() {
        let spy = SpyLogHandler()

        spy.debug("d")
        spy.info("i")
        spy.notice("n")
        spy.warning("w")
        spy.error("e")

        XCTAssertEqual(spy.records.map(\.level), [.debug, .info, .notice, .warning, .error])
        XCTAssertEqual(spy.records.map(\.message), ["d", "i", "n", "w", "e"])
    }

    func test_convenienceMethod_passesMetadata() {
        let spy = SpyLogHandler()

        spy.error("실패", metadata: ["orderID": "42"])

        XCTAssertEqual(spy.records.first?.metadata, ["orderID": "42"])
    }

    // MARK: - 전역 파사드 Log

    func test_log_forwardsAllLevelsToBootstrappedHandler() {
        let spy = SpyLogHandler()
        Log.bootstrap(spy)
        addTeardownBlock { Log.bootstrap(NoopLogger()) }   // 실패 경로에서도 전역 상태 정리 보장

        Log.debug("d")
        Log.info("i")
        Log.notice("n")
        Log.warning("w", metadata: ["k": "v"])
        Log.error("e")

        XCTAssertEqual(spy.records.map(\.level), [.debug, .info, .notice, .warning, .error])
        XCTAssertEqual(spy.records.map(\.message), ["d", "i", "n", "w", "e"])
        XCTAssertEqual(spy.records[3].metadata, ["k": "v"])
    }

    func test_log_capturesCallerLocation_notFacadeLocation() {
        let spy = SpyLogHandler()
        Log.bootstrap(spy)
        addTeardownBlock { Log.bootstrap(NoopLogger()) }

        let expectedLine = UInt(#line) + 1
        Log.error("loc")

        // 파사드(Log.swift)가 아니라 이 호출부의 file/line 이 그대로 전달돼야 한다.
        XCTAssertEqual(spy.records.first?.file, #fileID)
        XCTAssertEqual(spy.records.first?.line, expectedLine)
    }

    // MARK: - 동시성

    func test_log_underConcurrentAccess_doesNotCrash() async {
        addTeardownBlock { Log.bootstrap(NoopLogger()) }

        // 동시 bootstrap(백엔드 스왑) + 동시 log(백엔드 획득) 를 던져 Log 의 잠금을 검증한다.
        // 대상 백엔드는 무상태 NoopLogger — 핸들러 쪽 경합 없이 Log 잠금만 스트레스한다.
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask { Log.bootstrap(NoopLogger()) }
                group.addTask { Log.info("concurrent \(i)") }
            }
        }
    }

    // MARK: - OSLogger.formatMetadata (순수 조립 로직)

    func test_formatMetadata_empty_returnsEmptyString() {
        XCTAssertEqual(OSLogger.formatMetadata([:]), "")
    }

    func test_formatMetadata_sortsKeysAndQuotesValues() {
        XCTAssertEqual(OSLogger.formatMetadata(["b": "2", "a": "1"]), " a=\"1\" b=\"2\"")
    }

    func test_formatMetadata_valueWithSpace_keepsBoundaryUnambiguous() {
        XCTAssertEqual(OSLogger.formatMetadata(["path": "a b", "n": "1"]), " n=\"1\" path=\"a b\"")
    }

    // MARK: - NoopLogger

    func test_noopLogger_doesNothing() {
        let noop = NoopLogger()
        noop.error("무시됨")   // 크래시·부작용 없어야 함
    }

    // MARK: - OSLogger (필터 스모크)

    func test_osLogger_belowMinimumLevel_doesNotCrash() {
        let logger = OSLogger(minimumLevel: .warning)
        logger.debug("걸러짐")     // 필터 되는 경로
        logger.error("통과됨")     // 통과 경로
        // os 출력은 관측 불가 — 양 갈래 모두 크래시 없음만 확인
    }
}

/// 테스트용 스파이 백엔드 — 호출을 순서대로 기록한다.
/// 테스트는 단일 스레드로 호출하므로 별도 동기화는 두지 않는다.
final class SpyLogHandler: LogHandler, @unchecked Sendable {
    struct Record {
        let level: LogLevel
        let message: String
        let metadata: [String: String]
        let file: String
        let line: UInt
    }

    private(set) var records: [Record] = []

    func log(
        _ level: LogLevel,
        message: String,
        metadata: [String: String],
        file: String,
        function: String,
        line: UInt
    ) {
        records.append(Record(level: level, message: message, metadata: metadata, file: file, line: line))
    }
}
