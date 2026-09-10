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
    /// 개수만 들고 있다가 URL 이 필요해진 자리(공유 시트 썸네일·장소 카드)가 생겨 배열로 바꿨다.
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
    /// 개인방(`내 장소`)인가 — 헤더 액션 줄에서 `+`(초대)와 `⋮`(더보기)를 **뺄지**의 기준이다.
    ///
    /// 둘 다 개인방에는 놓을 것이 없다. PRD 「개인방」이 **초대 불가**·**삭제/나가기 금지**로
    /// 못박았고([SYS-006]도 "공동방에 타인을 초대할 때"로 한정한다), 더보기 메뉴는 편집(방장 전용)
    /// 과 나가기 둘뿐이라 개인방에서는 항목이 하나도 남지 않는다(시안 `004-5` Case 3 = 더보기
    /// 버튼 자체가 없음).
    ///
    /// 방 종류(`RoomType`)를 그대로 들지 않고 Bool 로 좁힌 건 표시 모델이 필요한 것이 "종류" 가
    /// 아니라 "이 두 버튼을 그리는가" 하나이기 때문이다.
    let isPersonal: Bool

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
            memberAvatarColors: memberAvatarColors,
            isPersonal: isPersonal
        )
    }
}

/// 삭제 확인 다이얼로그(시안 004-1-3-1)가 겨냥한 장소.
///
/// `mhDialog(item:)` 이 `Identifiable` 을 요구해 값 하나를 감쌌다. 진행 중 여부를 밖에 Bool 로
/// 따로 두지 않고 여기 담는 건, "다이얼로그는 닫혔는데 삭제 중" 같은 있을 수 없는 조합을
/// 타입으로 막기 위해서다.
/// 방 나가기 확인 다이얼로그(004-5). nil 이면 닫혀 있다.
struct RoomDetailLeave: Equatable, Identifiable {
    /// 내가 나가면 **방이 사라지는가** — 방장이 마지막 멤버인 경우다.
    ///
    /// 서버가 그렇게 동작하고(스펙: "방장+마지막 멤버면 방 삭제"), 별도의 방 삭제 API 도 없다.
    /// 문구로 그 사실을 알려 주지 않으면 사용자는 "나만 빠진다" 고 읽는다.
    let deletesRoom: Bool
    /// 요청을 보내고 기다리는 중 — 두 버튼을 모두 잠가 연타로 두 번 보내지 않는다.
    var isSubmitting = false
    /// 나가기가 실패했다. 다이얼로그는 열어 두고 문구만 바꿔 재시도할 수 있게 한다 —
    /// 닫아 버리면 "눌렀는데 아무 일도 없다" 로 보인다.
    var failed = false

    /// 화면에 하나만 뜬다 — 항목을 가릴 id 가 필요 없다.
    var id: String { "leave" }
}

/// 방장 위임 대상 고르기. 서버가 409(`OWNER_TRANSFER_REQUIRED`)로 요구했을 때만 선다.
///
/// **확정 시안이 없다**(Figma 3개 페이지 전수 확인 — 004-5 방편집/나가기 프레임도, API 스펙이
/// 말하는 "방장 위임 대상 선택 모달" 도 파일에 없다). 디자인이 오면 이 상태는 그대로 두고
/// 그리는 쪽(``RoomOwnerTransferCard``)만 맞추면 된다.
struct RoomOwnerTransfer: Equatable, Identifiable {
    let candidates: [RoomOwnerTransferCandidate]
    var selectedID: String?
    var isSubmitting = false
    /// 위임 또는 뒤이은 나가기가 실패했다.
    var failed = false

    var id: String { "ownerTransfer" }

    /// 고른 사람이 있고 요청이 진행 중이 아닐 때만 넘길 수 있다.
    var canSubmit: Bool { selectedID != nil && !isSubmitting }
}

/// 위임 후보 한 명 — 나를 뺀 이 방의 참여자.
struct RoomOwnerTransferCandidate: Equatable, Identifiable {
    let id: String
    let nickname: String
    let avatarColor: AvatarColor?
}

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
            memberAvatarColors: room.users.map(\.avatarColor),
            isPersonal: room.type == .personal
        )
    }
}

/// 정렬 드롭다운의 한글 표기. 기준 자체는 Domain ``PinSort`` 가 들고 **라벨만 화면이 붙인다** —
/// 홈이 `PinFilter.chipTitle` 로 같은 일을 한다(`HomeContentView.swift:421`).
///
/// **선언 순서가 곧 노출 순서다** — ``RoomDetailSortMenu`` 와 peek 의 `MHFilterBar` 가
/// `PinSort.allCases` 를 그대로 그린다. 순서는 시안 `2542:125333` 의 열린 드롭다운과 맞췄다.
/// 첫 항목이 기본 선택은 아니다 — 기본은 `.all` 이다(PRD "5종이며 기본값은 `전체`다").
///
/// **방 상세와 방 리스트가 같은 5가지를 쓴다** — 003-1 ① 이 "필터 drop down : 5가지로 필터링하여
/// 볼 수 있다 / '전체'로 기본 선택되어있다" 로 못박아 두 화면의 항목이 같다.
extension PinSort {
    var menuTitle: String {
        switch self {
        case .recommended: "꾹 Pick"
        case .all: "전체"
        case .latest: "최신순"
        case .distance: "거리순"
        case .comment: "코멘트순"
        }
    }
}

/// 카테고리 칩의 한글 표기. 값 집합(3종 고정)은 Domain ``PlaceCategoryFilter`` 가 든다.
extension PlaceCategoryFilter {
    var chipTitle: String {
        switch self {
        case .all: "전체"
        case .cafe: "카페"
        case .restaurant: "음식점"
        }
    }
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

// MARK: - 더미 데이터

extension RoomDetailRoom {
    static let sample = RoomDetailRoom(
        title: "가나다라마바사아자차카타파하다",
        memo: "memo",
        locationCount: 1_000,   // 상한(999) 을 넘겨 "999+개" 표기를 프리뷰에서 확인한다
        memberAvatarColors: [.red, .redOrange, .orange, .green],
        isPersonal: false
    )

    /// 개인방(`내 장소`) — 헤더에 `+`·`⋮` 가 빠진 모양을 프리뷰에서 확인한다.
    static let personalSample = RoomDetailRoom(
        title: Room.personalDisplayName,
        memo: "",
        locationCount: 3,
        memberAvatarColors: [.red],
        isPersonal: true
    )

    /// 멤버 7명 — PRD 「방 멤버 아바타」의 "아바타 3개 + 카운터 `4`" 예시가 그려지는 방.
    /// 4명(``sample``)과 나란히 두면 경계(5명)가 눈에 보인다.
    static let crowdedSample = RoomDetailRoom(
        title: "사람 많은 방",
        memo: "멤버 7명",
        locationCount: 12,
        memberAvatarColors: [.red, .redOrange, .orange, .green, .cyan, .blue, .purple],
        isPersonal: false
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
