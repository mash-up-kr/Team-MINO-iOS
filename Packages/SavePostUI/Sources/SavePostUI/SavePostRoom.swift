import DesignSystem

/// 게시물 저장 시트에 한 줄로 뜨는 방. Figma `Card_Room`.
///
/// 홈은 `Domain.Room`, 익스텐션은 `Core.SharedRoom` 을 들고 있어 서로 타입이 다르다 —
/// 시트가 어느 쪽도 모르도록 표시에 필요한 값만 옮겨 담는 표현용 value type 이다.
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
