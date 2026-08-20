import DesignSystem

/// 방 상세의 케밥 메뉴 항목을 만드는 자리. View 밖 순수 함수라 항목 구성이 단위 테스트로 고정된다.
enum RoomDetailMenuCatalog {
    /// 장소 카드 케밥 메뉴. Figma `004-2-1_장소 더보기 클릭`.
    static func locationItems(onSelect: @escaping (RoomDetailMenuItemID) -> Void) -> [MHMenuItem] {
        RoomDetailMenuItemID.allCases.map { id in
            MHMenuItem(id.title) { onSelect(id) }
        }
    }
}
