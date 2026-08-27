import Domain

struct RoomDetailLocation: Identifiable, Equatable {
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

extension RoomDetailLocation {
    init(from pin: Pin) {
        self.init(
            id: pin.id.value,
            name: pin.place.name,
            address: pin.place.address,
            commentCount: pin.commentCount,
            photoCount: pin.images.count
        )
    }
}

extension RoomDetailRoom {
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
