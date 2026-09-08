import Domain

/// 서버에 낸 장소 조회 조건. 응답에 함께 실어 **늦게 온 응답을 버리는** 데 쓴다 — 기준을 연달아
/// 바꾸면 먼저 낸 요청이 나중에 도착할 수 있고, 그러면 사용자가 마지막에 고른 것과 다른 목록이
/// 화면에 남는다.
///
/// 방 상세와 방 리스트가 **같은 드롭다운·칩을 쓰고 같은 엔드포인트를 부른다**(003-1 ① · 004-1 ⑥)
/// 그래서 조건 타입도 하나다 — 두 벌을 두면 한쪽만 고쳐도 컴파일이 통과한다.
///
/// `RoomListAction` 이 public 이라(그 화면의 State·Action 이 모듈 밖으로 열려 있다) 이 타입도
/// 함께 열어 둔다 — 방 상세 쪽 `RoomDetailAction` 은 internal 이라 이 제약이 없다.
public struct PinQuery: Equatable, Sendable {
    public var sort: PinSort = .all
    public var category: PlaceCategoryFilter = .all

    public init(sort: PinSort = .all, category: PlaceCategoryFilter = .all) {
        self.sort = sort
        self.category = category
    }
}
