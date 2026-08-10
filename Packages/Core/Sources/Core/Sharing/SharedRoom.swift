import Foundation

/// 익스텐션이 방 목록을 그리는 데 필요한 최소 정보.
///
/// **도메인 Entity 가 아니라 본앱·익스텐션이 함께 보는 표시 포맷**이다. 두 타깃은 서로 다른
/// 바이너리라 App 소스를 공유할 수 없어, 둘 다 링크하는 Core 에 둔다.
/// 서버가 붙으면 `Domain.Room` → `SharedRoom` 매핑을 만든다.
public struct SharedRoom: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let memo: String?
    public let placeCount: Int

    public init(id: String, name: String, memo: String? = nil, placeCount: Int) {
        self.id = id
        self.name = name
        self.memo = memo
        self.placeCount = placeCount
    }
}
