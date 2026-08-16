import Alamofire
import Foundation
import Testing
@testable import Networking

@Suite("재시도")
struct RetryTests {
    @Test("GET 5xx 는 한 번 더 시도한다")
    func retriesIdempotentServerError() async throws {
    let (sut, stub) = makeSUT(interceptor: testRetryPolicy)
    stub.stub.statusCode = 503

    _ = await capture { try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

    #expect(stub.recorded.count == 2)   // 최초 + 재시도 1회
    }

    @Test("retryLimit 을 소진하면 마지막 실패를 그대로 전파한다")
    func propagatesLastFailure() async throws {
    let (sut, stub) = makeSUT(interceptor: testRetryPolicy)
    stub.stub.statusCode = 500

    let error = await capture { try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

    #expect(error == .server(statusCode: 500))
    }

    @Test("4xx 는 재시도하지 않는다 — 다시 불러도 같은 답이다")
    func doesNotRetryClientError() async throws {
    let (sut, stub) = makeSUT(interceptor: testRetryPolicy)
    stub.stub.statusCode = 403
    stub.stub.body = Data(#"{"errorCode":"FORBIDDEN","message":"권한 없음"}"#.utf8)

    _ = await capture { try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

    #expect(stub.recorded.count == 1)
    }

    // POST 재시도는 중복 생성을 부른다. 특히 링크 분석(POST /rooms/{id}/pins)은
    // 재시도하면 분석 잡이 두 번 생긴다 — Alamofire 기본값이 멱등 메서드만 재시도한다.
    @Test("POST 5xx 는 재시도하지 않는다")
    func doesNotRetryPost() async throws {
    let (sut, stub) = makeSUT(interceptor: testRetryPolicy)
    stub.stub.statusCode = 503

    _ = await capture {
        try await sut.request(Endpoint<OkResponse>(path: "api/v1/rooms/r1/pins", method: .post))
    }

    #expect(stub.recorded.count == 1)
    }

    @Test("전송 실패도 한 번 더 시도한다")
    func retriesTransportFailure() async throws {
    let (sut, stub) = makeSUT(interceptor: testRetryPolicy)
    stub.stub.error = URLError(.networkConnectionLost)

    _ = await capture { try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }

    #expect(stub.recorded.count == 2)
    }

    // 재시도의 존재 이유인 경로다. 이게 없으면 재시도가 1차 응답을 돌려주거나
    // 2차 본문 디코딩을 빠뜨려도 전부 초록이다.
    @Test("1차 503 → 2차 200 이면 2차 응답을 돌려준다")
    func retrySucceedsAndReturnsSecondResponse() async throws {
    let (sut, stub) = makeSUT(interceptor: testRetryPolicy)
    stub.enqueue([
        .init(statusCode: 503, body: Data()),
        .init(statusCode: 200, body: Data(roomsJSON.utf8)),
    ])

    let rooms = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms"))

    #expect(stub.recorded.count == 2)
    #expect(rooms.first?.name == "우리 동네 맛집")
    }

    @Test("PUT·DELETE 도 멱등이라 재시도한다", arguments: [Networking.HTTPMethod.put, .delete])
    func retriesOtherIdempotentMethods(_ method: Networking.HTTPMethod) async throws {
    let (sut, stub) = makeSUT(interceptor: testRetryPolicy)
    stub.stub.statusCode = 503

    _ = await capture {
        _ = try await sut.request(Endpoint<OkResponse>(path: "api/v1/rooms/r1", method: method))
    }

    #expect(stub.recorded.count == 2)
    }
}
