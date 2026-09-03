import DesignSystem

/// 게시물 저장 시트에 한 줄로 뜨는 방. Figma `Card_Room`.
///
/// 홈과 공유 익스텐션이 각자 `Domain.Room` 을 자기 매핑으로 옮겨 담는 표현용 value type 이다.
/// 시트가 도메인을 모르게 해, 진입점이 늘어도 시트를 고치지 않는다.
public struct SavePostRoom: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let memo: String?
    /// "장소 N개" 에 들어갈 수.
    public let placeCount: Int
    public let thumbnail: MHRoomThumbnailKind

    public init(
        id: String,
        name: String,
        memo: String? = nil,
        placeCount: Int,
        thumbnail: MHRoomThumbnailKind = .color(.pink)
    ) {
        self.id = id
        self.name = name
        self.memo = memo
        self.placeCount = placeCount
        self.thumbnail = thumbnail
    }
}
