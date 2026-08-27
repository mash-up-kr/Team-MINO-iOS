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
    private static let countCap = 999

    let title: String
    let memo: String
    /// 방에 담긴 장소 수. 서버가 주는 방 집계값이라 지금 받아 온 페이지의 장소 수와는 다르다.
    /// 표시 문자열이 아니라 수로 들고 있어야 삭제 후 헤더를 다시 조회 없이 맞출 수 있다.
    let locationCount: Int
    let memberCount: Int

    var locationCountText: String {
        locationCount > Self.countCap ? "\(Self.countCap)+개" : "\(locationCount)개"
    }

    /// 장소 하나를 지운 뒤의 방. 삭제는 서버 집계를 다시 받아오지 않으므로 화면에서 1 을 뺀다 —
    /// 안 빼면 카드는 사라졌는데 헤더만 "N개" 그대로라 방금 한 조작이 안 먹은 것처럼 보인다.
    func removingOneLocation() -> RoomDetailRoom {
        RoomDetailRoom(
            title: title,
            memo: memo,
            locationCount: max(0, locationCount - 1),
            memberCount: memberCount
        )
    }
}

/// 삭제 확인 다이얼로그(시안 004-1-3-1)가 겨냥한 장소.
///
/// `mhDialog(item:)` 이 `Identifiable` 을 요구해 값 하나를 감쌌다. 진행 중 여부를 밖에 Bool 로
/// 따로 두지 않고 여기 담는 건, "다이얼로그는 닫혔는데 삭제 중" 같은 있을 수 없는 조합을
/// 타입으로 막기 위해서다.
struct RoomDetailDeletion: Equatable, Identifiable {
    let locationID: RoomDetailLocation.ID
    /// 확인을 누른 뒤 응답을 기다리는 중 — 두 버튼을 모두 잠가 연타로 두 번 지우는 걸 막는다.
    var isSubmitting = false

    var id: RoomDetailLocation.ID { locationID }
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
    init(from room: Room) {
        self.init(
            title: room.name,
            memo: room.description ?? "",
            locationCount: room.pinCount,
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
        locationCount: 1_000,   // 상한(999) 을 넘겨 "999+개" 표기를 프리뷰에서 확인한다
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
