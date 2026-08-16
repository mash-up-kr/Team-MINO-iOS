import Alamofire
import Foundation
import Logging

/// 요청·응답을 로그로 남기는 Alamofire `EventMonitor`.
///
/// **`Authorization` 헤더는 절대 찍지 않는다.** 응답 본문과 전체 URL 은 DEBUG 빌드에서만 남긴다 —
/// 초대 코드가 경로에 들어가고(`/invitations/{code}`) 본문에 닉네임·방 이름이 실리므로,
/// 릴리즈 기기 로그에 쌓이면 안 된다.
struct NetworkLogger: EventMonitor {
    let queue = DispatchQueue(label: "com.mashup.teamMino.networking.log")

    // `requestDidResume` 시점에는 URLRequest 가 아직 없다(항상 nil). 이 훅이 만들어진 뒤 불린다.
    func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        Log.debug("→ 요청", metadata: [
            "method": urlRequest.httpMethod ?? "-",
            "url": Self.urlForLog(urlRequest.url),
        ])
    }

    // `serializingData` 는 **제네릭** 오버로드를 부른다. `DataResponse<Data?, AFError>` 쪽을
    // 구현하면 비직렬화 `response()` 경로에서만 불려 로그가 한 줄도 남지 않는다.
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        let status = response.response?.statusCode
        var metadata = [
            "method": request.request?.httpMethod ?? "-",
            "url": Self.urlForLog(request.request?.url),
            "status": status.map(String.init) ?? "-",
            "elapsed": String(format: "%.3fs", response.metrics?.taskInterval.duration ?? 0),
        ]

        #if DEBUG
        if let data = response.data, !data.isEmpty {
            metadata["body"] = String(decoding: data.prefix(2048), as: UTF8.self)
        }
        #endif

        if let status, (200..<300).contains(status) {
            Log.debug("← 응답", metadata: metadata)
        } else {
            Log.warning("← 응답 실패", metadata: metadata)
        }
    }

    /// 재시도가 일어났다는 사실이 로그에 남지 않으면 지연 원인을 설명할 수 없다.
    func request(_ request: Request, didCreateTask task: URLSessionTask) {
        guard request.retryCount > 0 else { return }
        Log.warning("↻ 재시도", metadata: [
            "url": Self.urlForLog(request.request?.url),
            "attempt": String(request.retryCount + 1),
        ])
    }

    /// 릴리즈에서는 쿼리를 떼고 경로만 남긴다 — 초대 코드·검색어가 기기 로그에 쌓이지 않게 한다.
    private static func urlForLog(_ url: URL?) -> String {
        guard let url else { return "-" }
        #if DEBUG
        return url.absoluteString
        #else
        return url.path()
        #endif
    }
}
