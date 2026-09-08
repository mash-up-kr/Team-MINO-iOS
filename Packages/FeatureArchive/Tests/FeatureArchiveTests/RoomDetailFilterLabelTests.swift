import Domain
import Testing
@testable import FeatureArchive

/// 정렬 드롭다운과 카테고리 칩의 **항목 구성·순서·표기**를 고정한다.
///
/// 무엇으로 거르고 줄 세우는지는 서버가 하고(`GET /api/v1/pins` 의 `sort`·`category`), 화면이 지는
/// 책임은 "무엇을 어떤 순서로 보여 주는가" 뿐이라 여기서 그것만 본다. 정렬 결과 자체를 단언하던
/// 테스트(`RoomDetailSortingTests`·업종 필터 테스트)는 서버 몫이 되며 함께 걷었다.
@Suite("정렬·카테고리 표기")
struct RoomDetailFilterLabelTests {
    // 시안 `2542:125333` 의 열린 드롭다운이 이 순서다. `allCases` 를 그대로 그리므로
    // 선언 순서가 어긋나면 화면 순서도 어긋난다.
    @Test("정렬은 5종이고 순서는 꾹 Pick → 전체 → 최신순 → 거리순 → 코멘트순이다")
    func sortOrder() {
        #expect(PinSort.allCases.map(\.menuTitle) == ["꾹 Pick", "전체", "최신순", "거리순", "코멘트순"])
    }

    // 첫 항목이 기본 선택은 아니다 — PRD 「목록 정렬 기준」이 "5종이며 기본값은 `전체`다" 로 못박았다.
    @Test("정렬 기본값은 첫 항목이 아니라 '전체' 다")
    func sortDefaultIsAll() {
        #expect(RoomDetailState(room: .sample).sort == .all)
        #expect(PinSort.allCases.first == .recommended)
    }

    // 거리순만 좌표를 요구한다 — 좌표 없이 보내면 서버가 400 이라 화면이 먼저 받아 둬야 한다.
    @Test("좌표를 요구하는 기준은 거리순 하나다")
    func onlyDistanceRequiresOrigin() {
        #expect(PinSort.allCases.filter(\.requiresOrigin) == [.distance])
    }

    // PRD 「카테고리 필터」 = 3종 고정, 기본값 `전체`. 비목표에도 동적 생성 금지가 명시돼 있고
    // 서버 `category` 파라미터도 같은 3종 enum 이라 값 집합이 양쪽에서 고정된다.
    @Test("카테고리 칩은 전체·카페·음식점 3종 고정이다")
    func categoryChips() {
        #expect(PlaceCategoryFilter.allCases.map(\.chipTitle) == ["전체", "카페", "음식점"])
    }

    @Test("카테고리 기본값은 '전체' 다")
    func categoryDefaultIsAll() {
        #expect(RoomDetailState(room: .sample).category == .all)
        #expect(PlaceCategoryFilter.allCases.first == .all)
    }
}
