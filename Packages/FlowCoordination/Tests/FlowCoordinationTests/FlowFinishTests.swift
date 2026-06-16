import Testing
@testable import FlowCoordination

@MainActor
struct FlowFinishTests {
    @Test("발사하면 bind 된 action 에 output 이 전달된다")
    func fires_output_to_bound_action() {
        let finish = FlowFinish<Int>()
        var received: Int?
        finish.bind { received = $0 }

        finish(42)

        #expect(received == 42)
    }

    @Test("이미 발사된 뒤 재발사는 무시된다")
    func ignores_double_fire() {
        let finish = FlowFinish<Int>()
        var count = 0
        finish.bind { _ in count += 1 }

        finish(1)
        finish(2)

        #expect(count == 1)
    }

    @Test("bind 가 없으면 발사해도 크래시 없이 무시된다")
    func no_crash_without_bind() {
        let finish = FlowFinish<Int>()
        finish(1)
        // 도달하면 통과
        #expect(Bool(true))
    }

    @Test("reset 후에는 다시 발사할 수 있다")
    func can_refire_after_reset() {
        let finish = FlowFinish<Int>()
        var values: [Int] = []
        finish.bind { values.append($0) }

        finish(1)
        finish.reset()
        finish(2)

        #expect(values == [1, 2])
    }

    @Test("Void 흐름은 인자 없이 호출된다")
    func void_callAsFunction() {
        let finish = FlowFinish<Void>()
        var fired = false
        finish.bind { fired = true }

        finish()

        #expect(fired)
    }

    @Test("재bind 하면 action 이 교체되고 다시 발사할 수 있다")
    func rebind_replaces_action_and_resets_didFire() {
        let finish = FlowFinish<Int>()
        var first: [Int] = []
        var second: [Int] = []

        finish.bind { first.append($0) }
        finish(1)                            // 첫 action 으로 발사 (didFire = true)

        finish.bind { second.append($0) }    // 재bind → action 교체 + didFire 리셋
        finish(2)                            // 두 번째 발사가 먹어야 함 (flowRoot onAppear 재bind 경로)

        #expect(first == [1])
        #expect(second == [2])
    }
}
