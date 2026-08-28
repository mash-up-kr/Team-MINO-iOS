import DesignSystem

/// 방 상세의 케밥 메뉴 항목을 만드는 자리. View 밖 순수 함수라 항목 구성이 단위 테스트로 고정된다.
enum RoomDetailMenuCatalog {
    /// 장소 카드 케밥 메뉴. Figma `004-2-1_장소 더보기 클릭`.
    static func locationItems(onSelect: @escaping (RoomDetailMenuItemID) -> Void) -> [MHMenuItem] {
        RoomDetailMenuItemID.allCases.map { id in
            MHMenuItem(id.title) { onSelect(id) }
        }
    }

    /// 헤더 케밥 메뉴의 항목 목록. Figma `004-5 방 더보기 버튼 클릭시`.
    ///
    /// 방장이면 편집·나가기 둘, 아니면 나가기 하나다(004-1 ② 2-2). `MHMenuItem` 은 라벨을 밖에서
    /// 읽을 수 없어 항목 **구성**은 이 식별자 목록으로 단언한다 — 뷰가 쓰는 건 아래 ``moreItems``.
    static func moreItemIDs(isOwner: Bool) -> [RoomDetailMoreMenuItemID] {
        RoomDetailMoreMenuItemID.allCases.filter { $0 != .editRoom || isOwner }
    }

    /// 헤더 케밥 메뉴. 구성은 ``moreItemIDs(isOwner:)`` 가, 그리기는 `MHMenu` 가 맡는다.
    static func moreItems(
        isOwner: Bool,
        onSelect: @escaping (RoomDetailMoreMenuItemID) -> Void
    ) -> [MHMenuItem] {
        moreItemIDs(isOwner: isOwner).map { id in
            MHMenuItem(id.title) { onSelect(id) }
        }
    }
}
