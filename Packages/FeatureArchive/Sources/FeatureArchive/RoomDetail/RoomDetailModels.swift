import Domain
import Foundation

struct RoomDetailLocation: Identifiable, Equatable {
    /// **핀** id. 같은 장소도 방마다 핀이 따로라 이 값은 방 안에서만 유일하다.
    let id: String
    /// **장소** id. 「다른 방에 공유」 후보 조회가 이 값으로 나간다
    /// (`GET /rooms?showHasPlaceId={placeId}` — place-api.md §3). 핀 id 로는 "어느 방에
    /// 있는지" 를 물을 수 없어 함께 들고 있는다.
    let placeID: String
    let name: String
    let address: String
    let commentCount: Int
    /// 출처 게시물의 사진. 없을 수 있다.
    ///
    /// 개수만 들고 있다가 URL 이 필요해진 자리(공유 시트 썸네일)가 생겨 배열로 바꿨다 —
    /// 개수를 따로 두면 사진과 어긋날 수 있어 ``photoCount`` 는 여기서 센다.
    let photos: [URL]
    /// 이 장소를 방에 저장한 사람. 시안 004-1 장소 카드 우하단의 아바타 자리다.
    /// 서버가 저장자를 안 실어 주면 nil 이고, 그때는 자리를 **비운다** — 익명 회색 원을 대신
    /// 띄우면 "이름 모를 누군가가 저장했다"로 읽혀 없는 정보를 있는 것처럼 보이게 한다.
    let saver: MemberProfile?

    /// `saver` 만 기본값을 갖는다 — 저장자를 모르는 자리(공유 시트로 넘어가는 값 등)가 있어서다.
    init(
        id: String,
        placeID: String,
        name: String,
        address: String,
        commentCount: Int,
        photos: [URL],
        saver: MemberProfile? = nil
    ) {
        self.id = id
        self.placeID = placeID
        self.name = name
        self.address = address
        self.commentCount = commentCount
        self.photos = photos
        self.saver = saver
    }

    var photoCount: Int { photos.count }

    /// 장소를 한 칸으로 줄여 보여 줄 때 쓰는 대표 사진 — 첫 장이다(기획 011-1 ②).
    var thumbnail: URL? { photos.first }
}

/// 방 헤더에 들어가는 방 정보.
struct RoomDetailRoom: Equatable {
    private static let countCap = 999

    let title: String
    let memo: String
    /// 방에 담긴 장소 수. 서버가 주는 방 집계값이라 지금 받아 온 페이지의 장소 수와는 다르다.
    /// 표시 문자열이 아니라 수로 들고 있어야 삭제 후 헤더를 다시 조회 없이 맞출 수 있다.
    let locationCount: Int
    /// 방 참여자들의 아바타 프리셋 번호. 헤더 아바타 pill 이 이 순서대로 얼굴을 늘어놓는다.
    /// 수가 아니라 목록으로 드는 건, 그리려면 몇 명인지가 아니라 **누구인지**를 알아야 하기 때문이다.
    let memberAvatarColors: [AvatarColor?]

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
            memberAvatarColors: memberAvatarColors
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
            placeID: pin.place.id.value,
            name: pin.place.name,
            address: pin.place.address,
            commentCount: pin.commentCount,
            photos: pin.images,
            saver: pin.createdBy
        )
    }
}

extension RoomDetailRoom {
    init(from room: Room) {
        self.init(
            title: room.name,
            memo: room.description ?? "",
            locationCount: room.pinCount,
            memberAvatarColors: room.users.map(\.avatarColor)
        )
    }
}

/// 지도 위 필터 드롭다운의 정렬 기준.
///
/// **방 상세(004-1 ⑥)와 방 리스트(003-1 ①)가 같은 5가지를 쓴다** — 003-1 ① 이 "필터 drop down :
/// 5가지로 필터링하여 볼 수 있다 / '전체'로 기본 선택되어있다" 로 못박아 두 화면의 항목이 같다.
/// 그래서 이름은 `RoomDetail*` 이지만 방 상세 전용 타입이 아니다(두 화면이 한 개념을 공유한다).
///
/// **선언 순서가 곧 드롭다운 노출 순서다** — ``RoomDetailSortMenu`` 와 peek 의 `MHFilterBar` 가
/// `allCases` 를 그대로 그린다. 순서는 시안 `004-1-3_방 상세 full_리스트형` 의 열린 드롭다운과 맞췄다.
/// 첫 항목이 기본 선택은 아니다 — 기본은 `.all` 이다(003-1 ① · 004-1 ① "'전체'로 기본 선택되어있다").
public enum RoomDetailSort: String, CaseIterable, Identifiable {
    case pick = "꾹 Pick"
    case all = "전체"
    case latest = "최신순"
    case distance = "거리순"
    case comment = "코멘트순"

    public var id: String { rawValue }
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

/// 방 상세 헤더 케밥(점 세 개) 메뉴의 항목. 시안 `004-5 방 더보기 버튼 클릭시`.
///
/// 004-1 ② 2-2 — "클릭 시 방 편집 (방장 시에만) / 방 나가기 드롭다운". **방장이 아니면 "방 편집" 은
/// 비활성이 아니라 아예 없다** — 목록 구성은 ``RoomDetailMenuCatalog/moreItemIDs(isOwner:)`` 가 정한다.
enum RoomDetailMoreMenuItemID: String, CaseIterable {
    case editRoom
    case leaveRoom

    var title: String {
        switch self {
        case .editRoom: "방 편집"
        case .leaveRoom: "방 나가기"
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
        memberAvatarColors: [.red, .redOrange, .orange, .green]
    )
}

extension RoomDetailLocation {
    static let samples: [RoomDetailLocation] = (0..<8).map { index in
        RoomDetailLocation(
            id: "sample-\(index)",
            placeID: "sample-place-\(index)",
            name: "레이어스튜디오 10",
            address: "서울 성동구 상원4길 10",
            commentCount: 1000,
            photos: (0..<5).compactMap { URL(string: "https://picsum.photos/seed/mino-\(index)-\($0)/400/400") },
            saver: MemberProfile(
                id: MemberID("user-000\(index % 4 + 1)"),
                nickname: "저장자\(index)",
                avatarColor: AvatarColor.allCases[index % AvatarColor.allCases.count]
            )
        )
    }
}
