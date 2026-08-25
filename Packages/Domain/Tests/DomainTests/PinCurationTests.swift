import Foundation
import Testing
@testable import Domain

@Suite("PinCuration — 꾹 Pick·최신순 정책")
struct PinCurationTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func pin(_ id: String, daysAgo: Double) -> Pin {
        Pin(
            id: PinID(id),
            roomID: RoomID("r1"),
            category: .worthVisiting,
            title: "장소 \(id)",
            address: "주소 \(id)",
            createdAt: now.addingTimeInterval(-daysAgo * 86_400)
        )
    }

    private var pins: [Pin] {
        (0..<10).map { pin("p\($0)", daysAgo: Double($0) * 5) }
    }

    @Test("꾹 Pick 은 가장 오래된 상위 30% 를 오래된 순으로 낸다")
    func pick() {
        #expect(PinCuration.pick(from: pins).map(\.id.value) == ["p9", "p8", "p7"])
    }

    @Test("꾹 Pick 은 목록이 짧아도 최소 1건은 남긴다")
    func pickKeepsAtLeastOne() {
        let single = [pin("only", daysAgo: 3)]
        #expect(PinCuration.pick(from: single).count == 1)
    }

    @Test("최신순은 전체를 최신 순으로 재정렬한다 — 기간으로 걸러내지 않는다")
    func latest() {
        let result = PinCuration.latest(from: pins)
        #expect(result.map(\.id.value) == (0..<10).map { "p\($0)" })
        #expect(result.count == pins.count)   // 14일 넘은 장소(p3~p9)도 지워지지 않는다
    }

    @Test("빈 목록은 두 정책 모두 빈 목록이다")
    func emptyInput() {
        #expect(PinCuration.pick(from: []).isEmpty)
        #expect(PinCuration.latest(from: []).isEmpty)
    }
}
