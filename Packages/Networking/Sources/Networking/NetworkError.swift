import Foundation

/// 네트워크 인프라 계층의 오류. 이 타입은 Networking 내부에 격리되며
/// Domain 으로 새어 나가면 안 된다. (Data 계층에서 DomainError 로 변환)
///
/// 서버 에러 응답은 `{"errorCode": String, "message": String}` 포맷이 계약이다(envelope 밖).
/// 그 포맷이 아닌 응답이 오면 `decodingFailed` 로 던지고 본문 앞부분을 로그에 남긴다 —
/// 계약 위반을 조용히 삼키지 않기 위해서다.
///
/// `errorCode` 값 목록은 서버가 각 피쳐 PR 에서 확정하므로 `String` 으로 든다.
/// enum 으로 닫으면 모르는 코드를 만났을 때 디코딩이 깨진다.
public enum NetworkError: Error, Equatable, Sendable {
    case invalidURL
    case badRequest(code: String, message: String)
    /// 계약을 어긴 401(본문이 없거나 우리 포맷이 아님)도 이 케이스로 받으므로 옵셔널이다.
    /// `unexpectedErrorFormat` 으로 보내면 다른 4xx 와 뭉뚱그려져 화면이 재인증을 안 한다.
    case unauthorized(code: String?, message: String?)
    /// 멤버십·방장·작성자 검증 실패. 방·핀 API 전반이 쓴다.
    case forbidden(code: String, message: String)
    case notFound(code: String, message: String)
    /// 중복 등록 등.
    case conflict(code: String, message: String)
    /// 위에 해당하지 않는 4xx.
    case client(statusCode: Int, code: String, message: String)
    /// 5xx 및 4xx·2xx 가 아닌 상태코드. **429 는 여기가 아니라 4xx 경로**(`client`)로 간다.
    case server(statusCode: Int)
    /// 4xx 인데 본문이 `{errorCode, message}` 계약이 아니다. 상태코드는 보존한다 —
    /// 프록시·게이트웨이가 HTML 을 끼워 넣어도 화면이 404·403 을 알아볼 수 있어야 한다.
    case unexpectedErrorFormat(statusCode: Int, preview: String)
    /// 응답을 우리 타입으로 옮기지 못했다.
    case decodingFailed(description: String)
    /// 요청 본문을 JSON 으로 만들지 못했다. 보내는 쪽 실패라 `decodingFailed` 와 구분한다.
    case encodingFailed(description: String)
    /// 응답을 못 받았다.
    ///
    /// `reason` 으로 화면을 분기할 수는 있지만(`.notConnected` → "연결을 확인하세요"),
    /// **갈래가 완전하지 않다는 걸 알고 써야 한다** — 셀룰러 차단·로밍 해제·TLS 실패는
    /// 전부 `.unknown` 이다. 주 용도는 로그에서 원인을 좁히는 것이다.
    case transport(reason: TransportFailure)
    /// 화면 이탈 등으로 인한 정상 취소. 에러로 표시할 대상이 아니다.
    case cancelled
}

/// 서버 공통 에러 응답 본문. 성공 응답과 달리 `data` 로 감싸지 않는다.
struct APIErrorBody: Decodable {
    let errorCode: String
    let message: String
}

/// 전송 실패의 갈래. 지금은 화면이 구분하지 않지만, 로그에서 원인을 좁히는 데 쓴다.
public enum TransportFailure: String, Equatable, Sendable {
    case timedOut
    case notConnected
    case cannotFindHost
    case unknown
}

public extension NetworkError {
    /// 서버가 준 HTTP 상태코드. 응답을 받지 못했으면 nil.
    ///
    /// **Data 계층이 분기할 때 이걸 축으로 쓴다.** 같은 상황이 본문 모양에 따라 두 케이스로
    /// 갈리기 때문이다 — 프록시가 HTML 404 를 끼워 넣으면 `.notFound` 가 아니라
    /// `.unexpectedErrorFormat(404, _)` 로 온다. 케이스만 보고 분기하면 그 404 를 놓친다.
    var statusCode: Int? {
        switch self {
        case .badRequest:                       400
        case .unauthorized:                     401
        case .forbidden:                        403
        case .notFound:                         404
        case .conflict:                         409
        case .client(let statusCode, _, _):     statusCode
        case .server(let statusCode):           statusCode
        case .unexpectedErrorFormat(let statusCode, _): statusCode
        case .invalidURL, .decodingFailed, .encodingFailed, .transport, .cancelled: nil
        }
    }

    /// 서버가 준 `errorCode`. 계약대로 온 응답에만 있다.
    ///
    /// 값 목록은 서버가 피쳐 PR 마다 확정하므로 enum 으로 닫지 않는다.
    /// 화면 문구가 갈리는 경우(409 가 `ROOM_FULL` 인지 `ALREADY_JOINED` 인지)에 쓴다.
    var errorCode: String? {
        switch self {
        case .badRequest(let code, _),
             .forbidden(let code, _),
             .notFound(let code, _),
             .conflict(let code, _),
             .client(_, let code, _):
            code
        case .unauthorized(let code, _):
            code
        case .invalidURL, .server, .unexpectedErrorFormat,
             .decodingFailed, .encodingFailed, .transport, .cancelled:
            nil
        }
    }

    /// 로그에 남길 케이스 이름.
    ///
    /// ⚠️ **오류를 `String(describing:)` 으로 통째로 찍지 말고 이걸 쓴다.** 연관값에 서버 원문
    /// `message` 와 에러 본문 `preview` 가 들어 있는데, `OSLogger` 는 `.public` 으로 찍고
    /// 릴리즈 최소 레벨이 `warning` 이라 실패 경로의 값이 그대로 기기에 영구 기록된다 —
    /// `LogRedaction.body` 가 릴리즈에서 본문을 떼어내는 의미가 사라진다.
    /// 진단에 필요한 "무엇이 실패했나" 는 이름과 옆의 `statusCode`·`errorCode` 로 충분하다.
    var label: String {
        switch self {
        case .invalidURL:            "invalidURL"
        case .badRequest:            "badRequest"
        case .unauthorized:          "unauthorized"
        case .forbidden:             "forbidden"
        case .notFound:              "notFound"
        case .conflict:              "conflict"
        case .client:                "client"
        case .server:                "server"
        case .unexpectedErrorFormat: "unexpectedErrorFormat"
        case .decodingFailed:        "decodingFailed"
        case .encodingFailed:        "encodingFailed"
        // 갈래까지 붙인다 — `TransportFailure` 는 우리가 닫아둔 고정 어휘라 서버 값이 섞이지 않는다.
        case .transport(let reason): "transport(\(reason.rawValue))"
        case .cancelled:             "cancelled"
        }
    }
}
