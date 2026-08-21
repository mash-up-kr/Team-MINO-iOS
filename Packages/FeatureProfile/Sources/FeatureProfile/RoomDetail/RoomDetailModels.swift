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
    /// 방 대표 색(hex). 방 편집으로 넘길 때 피커 인덱스로 바뀐다.
    let color: String
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

/// 시트가 자기 바깥으로 내보내는 요청. 진입 화면(`ProfileTabView`)이 받아 처리한다.
/// 시트는 자기 안에서 딤을 동반한 모달을 띄울 수 없다 — `MHBottomSheet` 의 클립 경계 안이라 잘린다.
///
/// 장소는 식별자가 아니라 **값째** 싣는다. ID 만 보내면 받는 쪽이 자기 목록에서 재조회해야 하는데,
/// 시트에 주입된 목록과 조회처가 갈라지는 순간(서버 연동·필터) 조회 실패가 무음으로 삼켜진다.
enum RoomDetailOutput: Equatable {
    case close
    case shareLocation(RoomDetailLocation)
    /// 방 편집 화면으로. 장소와 같은 이유로 방도 **값째** 싣는다.
    case editRoom(RoomDetailRoom)
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
        color: "#00BDDE",   // Cyan — 방 색 피커의 6번째 칸
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
