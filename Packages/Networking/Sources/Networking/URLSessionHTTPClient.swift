import Alamofire
import Foundation
import Logging

/// Alamofire 기반 `HTTPClient` 구현체.
///
/// **Alamofire 는 이 파일 안에만 존재한다.** `AFError` 는 경계에서 전부 `NetworkError` 로
/// 번역되므로 바깥 레이어는 라이브러리를 알지 못한다.
public final class URLSessionHTTPClient: HTTPClient {
    private let baseURL: URL
    private let session: Session
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    /// 앱이 쓰는 유일한 초기화 경로. **Alamofire 타입이 시그니처에 드러나지 않는다.**
    public convenience init(baseURL: URL) {
        self.init(baseURL: baseURL, session: .mino)
    }

    /// 세션·디코더를 갈아끼우는 경로. 테스트 전용이라 `internal` 로 닫는다
    /// (`@testable import` 로 접근한다). public 으로 열면 Alamofire `Session` 이 밖으로 샌다.
    init(
        baseURL: URL,
        session: Session,
        decoder: JSONDecoder = APIDecoder.make(),
        encoder: JSONEncoder = APIEncoder.make()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    public func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        try await send(endpoint).data
    }

    public func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Page<Element> {
        let envelope = try await send(endpoint.endpoint)
        guard let pagination = envelope.pagination else {
            // 페이지네이션을 요청했는데 서버가 메타를 빠뜨렸다. nil 로 삼키면 hasNext 판단이
            // 조용히 틀어지므로 계약 위반으로 드러낸다.
            Log.error("페이지 응답에 pagination 이 없다", metadata: ["path": LogRedaction.path(endpoint.endpoint.path)])
            throw NetworkError.decodingFailed(description: "페이지 응답에 pagination 이 없음")
        }
        return Page(items: envelope.data, pagination: pagination)
    }

    // MARK: - 전송

    private func send<T>(_ endpoint: Endpoint<T>) async throws -> APIEnvelope<T> {
        let urlRequest = try makeURLRequest(endpoint)
        // `validate` 는 재시도를 위해 필요하다 — 이게 없으면 Alamofire 가 5xx 를 "성공" 으로 보고
        // `RetryPolicy` 를 아예 부르지 않는다. 상태코드 범위만 검사한다(콘텐츠 타입 검증은 뺀다).
        // 빈 본문은 모든 상태코드에서 허용한다. Alamofire 기본값은 `[204, 205]` 뿐이라
        // **204 가 아닌 2xx(예: 200)에 빈 본문**이 오면 `inputDataNilOrZeroLength` 로 잡혀
        // `.transport` 로 뭉개진다. (4xx·5xx 는 아래 상태코드 검사에 먼저 걸리므로 무관하다)
        let response = await session.request(urlRequest)
            .validate(statusCode: 200..<300)
            .serializingData(emptyResponseCodes: Set(100..<600))
            .response

        // 상태코드가 1차 진실이다. 검증 실패든 아니든 응답이 왔으면 상태코드로 판단한다.
        if let http = response.response, !(200..<300).contains(http.statusCode) {
            throw Self.mapFailure(
                statusCode: http.statusCode,
                data: response.data ?? Data(),
                path: endpoint.path,
                decoder: decoder
            )
        }

        switch response.result {
        case .failure(let error):
            throw Self.map(error)
        case .success(let data):
            // 서버 계약은 데이터 없는 성공도 `{"data":{"ok":true}}` 지만, 프록시나 일부
            // 엔드포인트가 204 + 빈 본문을 주면 디코딩이 반드시 실패한다.
            // "방 나가기가 실제로 성공했는데 화면은 오류" 가 되는 걸 막는다.
            if data.isEmpty, let ok = OkResponse(ok: true) as? T {
                return APIEnvelope(data: ok, pagination: nil)
            }
            do {
                return try decoder.decode(APIEnvelope<T>.self, from: data)
            } catch {
                Log.error("응답 디코딩 실패", metadata: [
                    "path": LogRedaction.path(endpoint.path),
                    "type": String(describing: T.self),
                    "reason": String(describing: error),
                ])
                throw NetworkError.decodingFailed(description: String(describing: error))
            }
        }
    }

    // MARK: - 요청 조립

    private func makeURLRequest<T>(_ endpoint: Endpoint<T>) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(endpoint.path),
            resolvingAgainstBaseURL: false
        ) else {
            throw NetworkError.invalidURL
        }
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }
        // URLComponents 는 `+` 를 인코딩하지 않는다. 서버가 form-urlencoded 규칙으로 읽으면
        // 공백이 되어 검색어·코드가 조용히 바뀐다.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")

        guard let url = components.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body = endpoint.body {
            switch body {
            case .json(let value):
                do {
                    request.httpBody = try encoder.encode(value)
                } catch {
                    throw NetworkError.encodingFailed(description: String(describing: error))
                }
                // body 가 있을 때만 붙인다 — GET 에 Content-Type 을 붙이면 일부 프록시가 이상하게 다룬다.
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        // 호출부가 넘긴 헤더가 기본값을 덮어쓴다.
        for (field, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        if let timeout = endpoint.timeout {
            request.timeoutInterval = timeout
        }
        return request
    }

    // MARK: - 오류 번역

    private static func map(_ error: AFError) -> NetworkError {
        if error.isExplicitlyCancelledError { return .cancelled }

        // 갈래를 나눠도 원본을 버리면 진단이 0 이다. TLS 거부·ATS 차단·토큰 주입 실패가
        // 전부 `.unknown` 으로 수렴하는데, 로그가 없으면 릴리즈에서 구분할 방법이 없다.
        // (클라이언트 측 오류 설명이라 서버 본문과 달리 PII 위험이 없다)
        Log.warning("전송 실패", metadata: [
            "error": String(describing: error),
            "underlying": error.underlyingError.map { String(describing: $0) } ?? "-",
        ])

        guard let urlError = error.underlyingError as? URLError else {
            return .transport(reason: .unknown)
        }
        switch urlError.code {
        case .cancelled:                                  return .cancelled
        case .timedOut:                                   return .transport(reason: .timedOut)
        case .notConnectedToInternet, .networkConnectionLost:
                                                          return .transport(reason: .notConnected)
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                                                          return .transport(reason: .cannotFindHost)
        default:                                          return .transport(reason: .unknown)
        }
    }

    /// 상태코드가 1차 진실이다. 에러 본문은 계약대로 왔을 때만 쓴다.
    private static func mapFailure(
        statusCode: Int,
        data: Data,
        path: String,
        decoder: JSONDecoder
    ) -> NetworkError {
        guard (400..<500).contains(statusCode) else {
            // 서버가 진단 정보를 본문에 담아 보내는 경우가 많다. 케이스에는 안 싣더라도 로그에는 남긴다.
            if !data.isEmpty {
                Log.warning("서버 오류 본문", metadata: [
                    "path": LogRedaction.path(path),
                    "status": String(statusCode),
                ].merging(LogRedaction.body(data)) { lhs, _ in lhs })
            }
            return .server(statusCode: statusCode)
        }

        guard let body = try? decoder.decode(APIErrorBody.self, from: data) else {
            let preview = String(decoding: data.prefix(200), as: UTF8.self)   // 값에만 싣는다(로그는 마스킹)

            // 본문 없는 401 은 인증 미들웨어의 정상 응답이라 조용히 넘긴다.
            // 다만 본문이 **있는데** 계약이 아니면(프록시가 낚아챈 HTML 등) 다른 상태코드와 똑같이 드러낸다.
            if statusCode == 401, data.isEmpty { return .unauthorized(code: nil, message: nil) }

            Log.error("에러 응답이 약속 포맷이 아님", metadata: [
                "path": LogRedaction.path(path),
                "status": String(statusCode),
            ].merging(LogRedaction.body(data)) { lhs, _ in lhs })
            if statusCode == 401 { return .unauthorized(code: nil, message: nil) }
            // 상태코드를 문자열에 녹이면 Data 계층이 분기할 수 없다 — 필드로 보존한다.
            return .unexpectedErrorFormat(statusCode: statusCode, preview: preview)
        }

        switch statusCode {
        case 400: return .badRequest(code: body.errorCode, message: body.message)
        case 401: return .unauthorized(code: body.errorCode, message: body.message)
        case 403: return .forbidden(code: body.errorCode, message: body.message)
        case 404: return .notFound(code: body.errorCode, message: body.message)
        case 409: return .conflict(code: body.errorCode, message: body.message)
        default:  return .client(statusCode: statusCode, code: body.errorCode, message: body.message)
        }
    }
}

extension Session {
    /// 이 앱의 기본 세션. **프로세스에 하나만 존재한다.**
    ///
    /// 클라이언트마다 새 `Session` 을 만들면, 그 클라이언트가 해제될 때 Alamofire 가
    /// 비행 중이던 요청을 `.sessionDeinitialized` 로 끝낸다. 이건 **명시적 취소가 아니고
    /// `underlyingError` 도 nil** 이라 우리 번역기에서 `.transport(.unknown)` 이 된다 —
    /// 화면을 벗어났을 뿐인데 "알 수 없는 오류" 가 뜨고, 원인이 unknown 이라 추적도 어렵다.
    /// 공유하면 그 실수가 성립하지 않는다(`Session` 은 thread-safe).
    ///
    /// - 타임아웃 10초: 재시도까지 포함한 총 소요를 20초 안에 묶기 위한 값이다.
    ///   Alamofire `RetryPolicy` 에는 전체 마감시한이 없어 타임아웃이 유일한 레버다.
    ///   ⚠️ `Endpoint.timeout` 을 올리면 재시도 때문에 **총 소요가 그 2배**가 된다
    ///   (30초로 올리면 멱등 요청은 최악 60초). 큰 값이 필요하면 재시도를 함께 검토한다.
    /// - 캐시 끔: 남이 방금 추가한 핀이 보여야 하는 앱이라 `URLCache` 를 쓰지 않는다.
    /// - 재시도 1회: Alamofire 기본값 그대로 — 상태코드는 `408·500·502·503·504` 만이고
    ///   (501·505 등은 제외), 메서드는 GET·PUT·DELETE·HEAD·OPTIONS·TRACE 다(POST·PATCH 제외).
    static let mino: Session = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        // `requestCachePolicy` 는 **읽기**만 막는다. 저장은 `urlCache` 가 결정하므로
        // 이것만으로는 응답이 계속 공유 디스크 캐시(URLCache.shared, 20MB)에 기록된다.
        // 방 이름·닉네임·위치가 앱 Caches 에 평문으로 쌓이지 않게 캐시 자체를 없앤다.
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil

        return Session(
            configuration: configuration,
            interceptor: minoRetryPolicy(),
            eventMonitors: [NetworkLogger()]
        )
    }()

    /// 재시도 정책. 테스트가 백오프만 줄여 **같은 정책을** 쓰도록 파라미터로 연다 —
    /// 값을 복사해 두면 프로덕션이 바뀌어도 테스트가 눈치채지 못한다.
    static func minoRetryPolicy(backoffScale: Double = 0.5) -> RetryPolicy {
        RetryPolicy(
            retryLimit: 1,
            exponentialBackoffBase: 2,
            exponentialBackoffScale: backoffScale
        )
    }
}
