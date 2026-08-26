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

    @Test("label 은 케이스 이름을 준다")
    func labelIsCaseName() {
        #expect(NetworkError.notFound(code: "X", message: "없음").label == "notFound")
        #expect(NetworkError.server(statusCode: 503).label == "server")
        #expect(NetworkError.cancelled.label == "cancelled")
        // 전송 실패는 갈래까지 — 우리가 닫아둔 고정 어휘라 서버 값이 섞이지 않는다.
        #expect(NetworkError.transport(reason: .timedOut).label == "transport(timedOut)")
    }

    // 릴리즈 로그는 `.public` 이라 label 에 연관값이 섞이면 서버 원문·에러 본문이
    // 그대로 기기에 남는다. `String(describing:)` 이라면 아래가 전부 통과한다.
    @Test("label 은 연관값(서버 원문·본문 미리보기)을 담지 않는다", arguments: [
        (NetworkError.notFound(code: "ROOM_NOT_FOUND", message: "방 '집들이' 를 찾을 수 없습니다"), "집들이"),
        (.badRequest(code: "INVALID_EMAIL", message: "user@example.com"), "@example.com"),
        (.unexpectedErrorFormat(statusCode: 404, preview: "<html>초대코드 ABC123XY</html>"), "ABC123XY"),
        (.decodingFailed(description: "codingPath: [roomName]"), "roomName"),
    ])
    func labelDropsAssociatedValues(_ error: NetworkError, _ leaked: String) {
        #expect(!error.label.contains(leaked))
    }
}
