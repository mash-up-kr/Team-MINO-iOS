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
    case all = "전체"
    case pick = "꾹 Pick"
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

/// 장소 카드 케밥(점 세 개) 메뉴의 항목.
///
/// 공유·삭제 2개로 확정됐다. 시안 목업에 함께 보이는 "장소 이동"은 재사용 Menu 컴포넌트의
/// 커스터마이징되지 않은 기본 라벨이라 반영하지 않는다.
enum RoomDetailMenuItemID: String, CaseIterable {
    case shareLocation
    case deleteLocation

    var title: String {
        switch self {
        case .shareLocation: "다른 방에 공유"
        case .deleteLocation: "장소 삭제"
        }
    }
}

/// 헤더 아래 카테고리 칩 목록.
///
/// 시안 004-1 ⑨ — "인스타에서 가져 온 저장 값에서 추가되는 형식(전시회 관련된 것을 저장 →
/// 전시회 필터 생성 / 음식점 관련 → 음식점 필터 생성)". 즉 **고정 집합이 아니라 방에 담긴
/// 장소들의 업종에서 만들어진다.** 목업의 "전체·카페·음식점" 3개는 그 방이 마침 그랬을 뿐이다.
enum RoomDetailCategoryList {
    /// 어떤 방에도 항상 있는 첫 칩. 기본 선택값이기도 하다.
    static let all = "전체"

    /// 방에 담긴 장소들의 업종을 **처음 나온 순서대로** 모은다.
    /// 알파벳/가나다 정렬을 하지 않는 건, 서버가 주는 순서가 곧 노출 우선순위이기 때문이다.
    static func make(from pins: [Pin]) -> [String] {
        var seen: Set<String> = []
        var result = [all]
        for category in pins.compactMap(\.place.category) where seen.insert(category).inserted {
            result.append(category)
        }
        return result
    }

    /// 선택한 칩에 해당하는 장소만 남긴다. "전체"면 그대로 둔다.
    static func filter(_ pins: [Pin], by category: String) -> [Pin] {
        guard category != all else { return pins }
        return pins.filter { $0.place.category == category }
    }
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
