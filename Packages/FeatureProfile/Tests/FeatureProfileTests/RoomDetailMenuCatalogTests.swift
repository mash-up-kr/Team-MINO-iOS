import Testing
@testable import FeatureProfile

/// 장소 케밥 메뉴의 항목 구성. View 밖 순수 함수라 라벨·순서·선택 전달을 결정적으로 검증한다.
struct RoomDetailMenuCatalogTests {
    @Test("장소 메뉴는 공유·삭제·이동 세 항목을 시안 순서대로 낸다")
    func locationItemsOrder() {
        #expect(RoomDetailMenuItemID.allCases == [.shareLocation, .deleteLocation, .moveLocation])
        #expect(RoomDetailMenuCatalog.locationItems { _ in }.count == 3)
    }

    @Test("각 항목의 라벨은 비어 있지 않고 서로 다르다")
    func locationItemLabels() {
        let titles = RoomDetailMenuItemID.allCases.map(\.title)
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(Set(titles).count == titles.count)
    }
}

// `MHMenuItem` 의 저장 프로퍼티는 DesignSystem 내부 접근 수준이라 라벨·action 을 밖에서 읽을 수 없다.
// 그래서 항목 개수까지만 여기서 걸고, 문구·순서는 위의 `RoomDetailMenuItemID` 로 검증한다.
