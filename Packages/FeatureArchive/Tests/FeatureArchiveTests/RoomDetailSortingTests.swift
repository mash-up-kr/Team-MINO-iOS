import Foundation
import Testing
import Domain
@testable import FeatureArchive

/// 정렬 규칙(Figma `1672:66212`). `now` 를 주입받는 순수 함수라 시각 의존 없이 결정적으로 검증된다.
struct RoomDetailSortingTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// `daysAgo` 일 전에 저장된 핀. id 로 순서를 눈으로 확인할 수 있게 둔다.
    private func pin(_ id: String, daysAgo: Double) -> Pin {
        Pin(
            id: PinID(id),
            roomID: "r1",
            category: .worthVisiting,
            title: "장소 \(id)",
            address: "주소 \(id)",
            createdAt: now.addingTimeInterval(-daysAgo * 86_400)
        )
    }

    /// 0·5·10·15·20·25·30·35·40·45 일 전 10건.
    private var pins: [Pin] {
        (0..<10).map { pin("p\($0)", daysAgo: Double($0) * 5) }
    }

    @Test("전체는 원본을 그대로 낸다")
    func all() {
        #expect(RoomDetailSorting.apply(.all, to: pins, now: now).map(\.id) == pins.map(\.id))
    }

    @Test("꾹 Pick 은 가장 오래된 상위 30% 를 오래된 순으로 낸다")
    func pick() {
        let result = RoomDetailSorting.apply(.pick, to: pins, now: now)
        // 10건의 30% = 3건. 가장 오래된 건 45일 전(p9) → 40일(p8) → 35일(p7).
        #expect(result.map(\.id.value) == ["p9", "p8", "p7"])
    }

    @Test("꾹 Pick 은 목록이 짧아도 최소 1건은 남긴다")
    func pickKeepsAtLeastOne() {
        let single = [pin("only", daysAgo: 3)]
        #expect(RoomDetailSorting.apply(.pick, to: single, now: now).count == 1)
    }

    @Test("최신순은 14일 이내만 최신 순으로 낸다")
    func latest() {
        let result = RoomDetailSorting.apply(.latest, to: pins, now: now)
        // 0·5·10 일 전만 14일 이내. 15일 전(p3)부터는 잘린다.
        #expect(result.map(\.id.value) == ["p0", "p1", "p2"])
    }

    @Test("최신순은 경계(정확히 14일 전)를 포함한다")
    func latestIncludesBoundary() {
        let boundary = [pin("edge", daysAgo: 14)]
        #expect(RoomDetailSorting.apply(.latest, to: boundary, now: now).count == 1)
    }

    @Test("거리순·코멘트순은 계산할 수 없어 원본을 그대로 낸다")
    func unsupportedSortsPassThrough() {
        for sort in [RoomDetailSort.distance, .comment] {
            #expect(RoomDetailSorting.apply(sort, to: pins, now: now).map(\.id) == pins.map(\.id))
        }
    }

    @Test("빈 목록은 어떤 정렬에도 빈 목록이다")
    func emptyInput() {
        for sort in RoomDetailSort.allCases {
            #expect(RoomDetailSorting.apply(sort, to: [], now: now).isEmpty)
        }
    }
}
