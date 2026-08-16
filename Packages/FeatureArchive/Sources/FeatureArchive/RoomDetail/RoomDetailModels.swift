import Domain
import Foundation

/// 방 상세 시트가 그리는 장소 한 건. 도메인 `Pin` 을 카드가 그릴 값으로 변환한 화면 표시 모델.
struct RoomDetailLocation: Identifiable, Equatable {
    /// `Pin.id` 를 그대로 쓴다 — 정렬이 바뀌어도 같은 장소는 같은 식별자여서 열린 메뉴가 엉뚱한 카드로 옮겨가지 않는다.
    let id: String
    let name: String
    let address: String
    let commentCount: Int
    let photoCount: Int
}

/// 방 헤더에 들어가는 방 정보.
struct RoomDetailRoom: Equatable {
    let title: String
    let memo: String
    let locationCountText: String
    let memberCount: Int
}

// MARK: - 도메인 → 표시 모델

extension RoomDetailLocation {
    /// `Pin` 에는 코멘트 수·사진 수가 없다. 시안이 요구하는 자리는 있으므로 상수로 채운다.
    // TODO: Pin 에 코멘트 수·사진 수가 생기면 매핑으로 교체한다.
    private static let placeholderCommentCount = 0
    /// 카드형(`004-1-3_카드형`)은 썸네일 2장을 나란히 놓는다 — `MHLocationCard(.expanded)` 가 배열 길이대로 나열한다.
    private static let placeholderPhotoCount = 2

    init(from pin: Pin) {
        self.init(
            id: pin.id.value,
            name: pin.title,
            address: pin.address,
            commentCount: Self.placeholderCommentCount,
            photoCount: Self.placeholderPhotoCount
        )
    }
}

extension RoomDetailRoom {
    /// 시안 상한 표기("999+개"). 넘어가면 자릿수가 헤더를 밀어낸다.
    private static let countCap = 999

    init(from room: Room) {
        self.init(
            title: room.name,
            memo: room.description ?? "",
            locationCountText: room.pinCount > Self.countCap ? "\(Self.countCap)+개" : "\(room.pinCount)개",
            memberCount: room.users.count
        )
    }
}

/// 툴바 좌측 드롭다운의 정렬 기준.
enum RoomDetailSort: String, CaseIterable, Identifiable {
    case pick = "꾹 Pick"
    case all = "전체"
    case latest = "최신순"
    case distance = "거리순"
    case comment = "코멘트순"

    var id: String { rawValue }
}

/// 툴바 우측 토글의 목록 표시 방식.
enum RoomDetailViewMode: CaseIterable {
    case list
    case grid
}

/// 장소 카드 케밥(점 세 개) 메뉴의 항목. 시안 순서 = 공유 → 삭제 → 이동.
enum RoomDetailMenuItemID: String, CaseIterable {
    case shareLocation
    case deleteLocation
    case moveLocation

    var title: String {
        switch self {
        case .shareLocation: "다른 방에 공유"
        case .deleteLocation: "장소 삭제"
        case .moveLocation: "장소 이동"
        }
    }
}

/// 헤더 아래 카테고리 칩.
enum RoomDetailCategory: String, CaseIterable, Identifiable {
    case all = "전체"
    case cafe = "카페"
    case restaurant = "음식점"

    var id: String { rawValue }
}

// MARK: - 더미 데이터

extension RoomDetailRoom {
    static let sample = RoomDetailRoom(
        title: "가나다라마바사아자차카타파하다",
        memo: "memo",
        locationCountText: "999+개",
        memberCount: 1
    )
}

extension RoomDetailLocation {
    static let samples: [RoomDetailLocation] = (0..<8).map { index in
        RoomDetailLocation(
            id: "sample-\(index)",
            name: "레이어스튜디오 10",
            address: "서울 성동구 상원4길 10",
            commentCount: 1000,
            photoCount: 5
        )
    }
}
