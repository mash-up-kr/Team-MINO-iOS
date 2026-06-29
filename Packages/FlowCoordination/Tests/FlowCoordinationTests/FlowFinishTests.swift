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

    @Test("재bind 는 action 만 교체하고 1회성은 유지한다 (재발사는 reset 후에만)")
    func rebind_replaces_action_but_keeps_one_shot() {
        let finish = FlowFinish<Int>()
        var first: [Int] = []
        var second: [Int] = []

        finish.bind { first.append($0) }
        finish(1)                            // 첫 발사 (didFire = true)

        finish.bind { second.append($0) }    // 재bind → action 만 교체, didFire 유지
        finish(2)                            // 이미 발사됐으므로 무시 (onAppear 재bind 가 1회성을 깨지 않음)
        #expect(first == [1])
        #expect(second.isEmpty)

        finish.reset()                       // 명시적 reset 후에만
        finish(3)                            // 재발사 허용
        #expect(second == [3])
    }
}
