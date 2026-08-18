import Foundation
import Testing
@testable import Networking

@Suite("NetworkError 축")
struct NetworkErrorTests {
    // 같은 404 가 본문 모양에 따라 두 케이스로 갈린다. 케이스만 보고 분기하면
    // 프록시가 HTML 을 끼워 넣은 404 를 놓친다 — 그래서 상태코드 축이 필요하다.
    @Test("같은 상태코드는 케이스가 달라도 같은 statusCode 를 준다")
    func statusCodeIsStableAcrossCases() {
        #expect(NetworkError.notFound(code: "NOT_FOUND", message: "없음").statusCode == 404)
        #expect(NetworkError.unexpectedErrorFormat(statusCode: 404, preview: "<html>").statusCode == 404)
        #expect(NetworkError.client(statusCode: 429, code: "TOO_MANY", message: "잠시 후").statusCode == 429)
        #expect(NetworkError.server(statusCode: 503).statusCode == 503)
    }

    @Test("응답을 못 받은 오류는 statusCode 가 없다", arguments: [
        NetworkError.transport(reason: .timedOut),
        .cancelled,
        .invalidURL,
        .decodingFailed(description: "-"),
        .encodingFailed(description: "-"),
    ])
    func noStatusCodeWithoutResponse(_ error: NetworkError) {
        #expect(error.statusCode == nil)
    }

    @Test("errorCode 는 계약대로 온 응답에만 있다")
    func errorCodeOnlyWhenContractHeld() {
        #expect(NetworkError.conflict(code: "ALREADY_JOINED", message: "이미 참여").errorCode == "ALREADY_JOINED")
        #expect(NetworkError.unexpectedErrorFormat(statusCode: 409, preview: "<html>").errorCode == nil)
        #expect(NetworkError.unauthorized(code: nil, message: nil).errorCode == nil)
    }
}
