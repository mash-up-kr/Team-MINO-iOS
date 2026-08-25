import Alamofire
import Foundation
import Logging

/// 요청·응답을 로그로 남기는 Alamofire `EventMonitor`.
///
/// **`Authorization` 헤더는 절대 찍지 않는다.** 릴리즈에서 남는 값은 `LogRedaction` 이 가린다 —
/// 초대 코드가 **경로에** 들어가므로(`/invitations/{code}`) 쿼리만 떼는 것으로는 부족하다.
struct NetworkLogger: EventMonitor {
    let queue = DispatchQueue(label: "com.mashup.teamMino.networking.log")

    // `requestDidResume` 시점에는 URLRequest 가 아직 없다(항상 nil). 이 훅이 만들어진 뒤 불린다.
    func request(_ request: Request, didCreateURLRequest urlRequest: URLRequest) {
        Log.debug("→ 요청", metadata: [
            "method": urlRequest.httpMethod ?? "-",
            "url": LogRedaction.url(urlRequest.url),
        ])
    }

    // `serializingData` 는 **제네릭** 오버로드를 부른다. `DataResponse<Data?, AFError>` 쪽을
    // 구현하면 비직렬화 `response()` 경로에서만 불려 로그가 한 줄도 남지 않는다.
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        let status = response.response?.statusCode
        // `response.metrics` 는 **마지막 시도**만 담는다(Alamofire 의 allMetrics.last).
        // 재시도가 있었다면 사용자가 기다린 시간은 그 합이라, 마지막 것만 찍으면
        // "왜 이 화면이 느렸나" 를 조사하는 사람이 네트워크를 용의선상에서 빼버린다.
        let elapsed = request.allMetrics.reduce(0) { $0 + $1.taskInterval.duration }
        var metadata = [
            "method": request.request?.httpMethod ?? "-",
            "url": LogRedaction.url(request.request?.url),
            "status": status.map(String.init) ?? "-",
            "elapsed": String(format: "%.3fs", elapsed),
            "attempts": String(request.retryCount + 1),
        ]

        #if DEBUG
        if let data = response.data, !data.isEmpty {
            metadata["body"] = String(decoding: data.prefix(2048), as: UTF8.self)
        }
        #endif

        // 취소는 화면 이탈·검색어 재입력마다 발생한다. warning 으로 남기면 릴리즈 로그가
        // 취소로 뒤덮여 진짜 실패가 묻힌다(`NetworkError.cancelled` 도 에러 표시 대상이 아니다).
        if response.error?.isExplicitlyCancelledError == true {
            Log.debug("← 취소", metadata: metadata)
        } else if let status, (200..<300).contains(status) {
            Log.debug("← 응답", metadata: metadata)
        } else {
            Log.warning("← 응답 실패", metadata: metadata)
        }
    }

    /// 재시도가 일어났다는 사실이 로그에 남지 않으면 지연 원인을 설명할 수 없다.
    func request(_ request: Request, didCreateTask task: URLSessionTask) {
        guard request.retryCount > 0 else { return }
        Log.warning("↻ 재시도", metadata: [
            "url": LogRedaction.url(request.request?.url),
            "attempt": String(request.retryCount + 1),
        ])
    }
}
