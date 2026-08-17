import Alamofire
import Foundation
import Testing
@testable import Networking

struct RoomDTO: Decodable, Sendable, Equatable {
    let id: String
    let name: String
    let createdAt: Date
}

struct CreateRoomBody: Encodable, Sendable {
    let name: String
    let color: String
}

let roomsJSON = """
{"data":[{"id":"room-1","name":"우리 동네 맛집","createdAt":"2026-08-16T07:01:31.566Z"}],
 "pagination":{"pageSize":20,"page":0,"hasNext":true}}
"""

/// 프로덕션과 **같은 정책**을 쓰되 백오프만 줄인다. 값을 복사하면 정책이 바뀌어도 안 깨진다.
let testRetryPolicy = Session.minoRetryPolicy(backoffScale: 0.01)

/// 테스트마다 **자기 stub 을 가진** 클라이언트를 만든다. 전역 상태가 없어 병렬 실행이 안전하다.
/// 기본 baseURL 은 **실재할 수 없는 호스트**(RFC 2606 `.invalid`)다.
/// 실 도메인을 쓰면 stub 이 요청을 못 잡았을 때(`canInit` 미스매치, 리다이렉트 후 헤더 유실 등)
/// 조용히 진짜 네트워크로 나가서, 로컬에선 붙었다 떨어졌다 하고 CI 에선 엉뚱한 오류로 실패한다.
func makeSUT(
    baseURL: String = "https://stub.invalid",
    interceptor: (any RequestInterceptor)? = nil
) -> (sut: URLSessionHTTPClient, stub: URLProtocolStub.Handle) {
    let (configuration, handle) = URLProtocolStub.makeSession()
    let session = Session(configuration: configuration, interceptor: interceptor)
    let client = URLSessionHTTPClient(baseURL: URL(string: baseURL)!, session: session)
    return (client, handle)
}

/// 던져진 오류를 `NetworkError` 로 받아온다. `AFError` 가 새면 여기서 드러난다.
func capture(_ body: () async throws -> Void) async -> NetworkError? {
    do {
        try await body()
        return nil
    } catch let error as NetworkError {
        return error
    } catch {
        Issue.record("NetworkError 가 아닌 오류가 새어 나왔다: \(error)")
        return nil
    }
}
