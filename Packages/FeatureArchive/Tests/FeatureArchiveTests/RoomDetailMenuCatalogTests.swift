import Testing
@testable import FeatureArchive

/// 장소 케밥 메뉴의 항목 구성. View 밖 순수 함수라 라벨·순서·선택 전달을 결정적으로 검증한다.
struct RoomDetailMenuCatalogTests {
    @Test("장소 메뉴는 공유·삭제 두 항목만 낸다 — \"장소 이동\"은 넣지 않는다")
    func locationItemsOrder() {
        #expect(RoomDetailMenuItemID.allCases == [.shareLocation, .deleteLocation])
        #expect(RoomDetailMenuCatalog.locationItems { _ in }.count == 2)
    }

    @Test("각 항목의 라벨은 비어 있지 않고 서로 다르다")
    func locationItemLabels() {
        let titles = RoomDetailMenuItemID.allCases.map(\.title)
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(Set(titles).count == titles.count)
    }

    @Test("방장 헤더 메뉴는 방 편집 → 방 나가기 순")
    func moreItemsForOwner() {
        #expect(RoomDetailMenuCatalog.moreItemIDs(isOwner: true) == [.editRoom, .leaveRoom])
        #expect(RoomDetailMenuCatalog.moreItems(isOwner: true) { _ in }.count == 2)
    }

    @Test("방장이 아니면 방 편집 항목이 아예 빠진다 — 비활성이 아니라 미표시")
    func moreItemsForMember() {
        #expect(RoomDetailMenuCatalog.moreItemIDs(isOwner: false) == [.leaveRoom])
        #expect(RoomDetailMenuCatalog.moreItems(isOwner: false) { _ in }.count == 1)
    }

    @Test("헤더 항목의 라벨은 시안 문구 그대로다")
    func moreItemLabels() {
        #expect(RoomDetailMoreMenuItemID.editRoom.title == "방 편집")
        #expect(RoomDetailMoreMenuItemID.leaveRoom.title == "방 나가기")
    }
}

// `MHMenuItem` 의 저장 프로퍼티는 DesignSystem 내부 접근 수준이라 라벨·action 을 밖에서 읽을 수 없다.
// 그래서 항목 개수까지만 여기서 걸고, 문구·순서는 위의 `RoomDetailMenuItemID` 로 검증한다.
