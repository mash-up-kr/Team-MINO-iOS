import Foundation
import Testing
@testable import Networking

@Suite("취소")
struct CancellationTests {
    // 실제 시나리오는 "요청을 보내놓고 화면을 나가는 것"이다. 응답이 즉시 오는 stub 으로는
    // 시작 전 취소만 재현되고, 정작 검증하고 싶은 비행 중 취소 경로를 안 탄다.
    @Test("응답 대기 중 취소하면 요청이 끊기고 cancelled 로 돌아온다")
    func cancelsInFlight() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.suspends = true   // 응답을 주지 않고 붙잡는다

        let task = Task { () -> NetworkError? in
            await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }
        }

        // 요청이 실제로 전송 계층까지 나간 뒤에 취소한다.
        try #require(await poll { !stub.recorded.isEmpty }, "요청이 전송 계층에 도달하지 않았다")
        task.cancel()

        #expect(await task.value == .cancelled)
        #expect(stub.recorded.count == 1)   // 취소는 재시도 대상이 아니다

        // 취소 전파는 URLProtocol 쪽에서 비동기로 관측되므로 기다린다.
        // suspends stub 은 스스로 끝나지 않으므로, stopLoading 이 불렸다면 취소가 닿은 것이다.
        #expect(await poll { stub.stopLoadingCount == 1 })
    }

    // 헤더가 도착한 뒤 화면을 나가는 경우. `response.response` 가 이미 채워져 있어서
    // 상태코드 검사가 취소보다 앞이면 **취소가 `.server(500)` 으로 뒤집힌다** —
    // 화면을 벗어났을 뿐인데 오류 UI 가 뜨고, 취소가 아니라 reduce 필터로도 안 걸러진다.
    @Test("에러 상태코드 헤더를 받은 뒤 취소해도 cancelled 다")
    func cancelAfterErrorHeader() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.statusCode = 500
        stub.stub.headerOnlyThenSuspend = true

        let task = Task { () -> NetworkError? in
            await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }
        }
        try #require(await poll { !stub.recorded.isEmpty }, "요청이 전송 계층에 도달하지 않았다")
        try await Task.sleep(for: .milliseconds(50))   // 헤더가 클라이언트에 전달될 시간
        task.cancel()

        #expect(await task.value == .cancelled)
    }

    @Test("시작 전에 취소해도 cancelled 로 돌아온다")
    func cancelsBeforeStart() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.suspends = true   // 완주해서 성공으로 끝나는 경합을 없앤다

        let task = Task { () -> NetworkError? in
            await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }
        }
        task.cancel()

        #expect(await task.value == .cancelled)
    }
}

/// 조건이 참이 될 때까지 기다린다. **상한이 있어야 한다** — 무한 스핀은 회귀가 생겼을 때
/// 테스트를 실패시키는 대신 CI 를 멈춘다(mvi-coordinator-di.md 7절: 무한 hang 금지).
func poll(timeout: Duration = .seconds(2), _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return true }
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(5))
    }
    return condition()
}
