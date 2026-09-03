import Testing
@testable import Core

@MainActor
struct PendingDeeplinkTests {
    @Test("보관한 딥링크를 꺼낸다")
    func consumesStoredDeeplink() {
        let pending = PendingDeeplink()
        pending.store(.invite(code: "AB12"))

        #expect(pending.consume() == .invite(code: "AB12"))
    }

    @Test("한 번 꺼내면 사라진다 — 같은 링크로 화면이 두 번 뜨지 않게")
    func consumesOnlyOnce() {
        let pending = PendingDeeplink()
        pending.store(.invite(code: "AB12"))

        _ = pending.consume()

        #expect(pending.consume() == nil)
    }

    @Test("보관 중 새 링크가 오면 나중 것이 이긴다")
    func lastStoreWins() {
        let pending = PendingDeeplink()
        pending.store(.invite(code: "AB12"))
        pending.store(.invite(code: "CD34"))

        #expect(pending.consume() == .invite(code: "CD34"))
    }

    @Test("보관한 게 없으면 nil 이다")
    func consumesNilWhenEmpty() {
        #expect(PendingDeeplink().consume() == nil)
    }
}
