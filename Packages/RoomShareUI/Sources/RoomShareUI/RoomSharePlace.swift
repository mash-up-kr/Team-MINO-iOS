import Foundation

/// 공유 시트 머리에 그릴 장소. 시트가 실제로 쓰는 것만 담는다(이름·주소·썸네일).
///
/// 저장 탭의 ``RoomDetailLocation`` 을 그대로 받지 않는 이유: 그 모델은 방 상세 전반에
/// 50곳 넘게 쓰이는 화면 모델이라 여기로 내리면 저장 탭이 통째로 흔들린다. 진입점마다
/// 자기 모델에서 이 값으로 옮겨 담는다 — 홈은 `Pin`, 저장 탭은 `RoomDetailLocation` 이다.
public struct RoomSharePlace: Equatable, Sendable {
    public let name: String
    public let address: String
    /// 출처 게시물 사진 중 첫 장. 없으면 자리표가 뜬다.
    public let thumbnail: URL?

    public init(name: String, address: String, thumbnail: URL?) {
        self.name = name
        self.address = address
        self.thumbnail = thumbnail
    }
}

/// 공유 시트 위에 덮은 「공동방 만들기」(011-1 ③)의 결과.
///
/// flow 자체는 띄우는 Feature 가 소유하지만(*UI 는 Coordinator 를 갖지 않는다) 그 **결과**는
/// 시트의 reduce 가 읽어야 해서 여기 둔다 — 만들었으면 목록을 다시 받고, 취소면 그대로 둔다.
public enum RoomShareCreateRoomResult: Equatable, Sendable {
    /// 방이 서버에 만들어졌다 — 공유 시트가 목록을 다시 받아야 새 방이 보인다.
    case created
    /// 만들지 않고 나왔다.
    case cancelled
}
