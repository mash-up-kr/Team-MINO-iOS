import Foundation

/// 방 상세 시트가 그리는 장소 한 건. 서버 연동 전까지 쓰는 화면 전용 표시 모델.
struct RoomDetailLocation: Identifiable, Equatable {
    let id: UUID = UUID()
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
    static let samples: [RoomDetailLocation] = (0..<8).map { _ in
        RoomDetailLocation(
            name: "레이어스튜디오 10",
            address: "서울 성동구 상원4길 10",
            commentCount: 1000,
            photoCount: 5
        )
    }
}
