import Foundation

/// 방 나열 정책 — 개인방(내 장소)을 먼저, 그다음 공동방.
/// 각 그룹 안의 상대 순서는 입력 순서를 유지한다(공동방 내부 순서는 서버가 준 순서 그대로 — 클라 정렬 없음).
public enum RoomOrdering {
    public static func personalFirst(_ rooms: [Room]) -> [Room] {
        rooms.filter { $0.type == .personal } + rooms.filter { $0.type == .shared }
    }
}
