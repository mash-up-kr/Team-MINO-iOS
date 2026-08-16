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
        while stub.recorded.isEmpty { await Task.yield() }
        task.cancel()

        let error = await task.value
        #expect(error == .cancelled)
        #expect(stub.recorded.count == 1)      // 취소는 재시도 대상이 아니다
        #expect(stub.cancellations == 1)       // 취소가 전송 계층까지 닿았다
    }

    @Test("시작 전에 취소해도 cancelled 로 돌아온다")
    func cancelsBeforeStart() async throws {
        let (sut, stub) = makeSUT()
        stub.stub.body = Data(#"{"data":[]}"#.utf8)

        let task = Task { () -> NetworkError? in
            await capture { _ = try await sut.request(Endpoint<[RoomDTO]>(path: "api/v1/rooms")) }
        }
        task.cancel()

        #expect(await task.value == .cancelled)
    }
}
