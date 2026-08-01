import Foundation

// MARK: - 표시 모델

/// 방 상세 시트가 그리는 장소 한 건. 서버 연동 전까지 쓰는 화면 전용 표시 모델이다
/// (Domain Entity 가 생기면 그쪽으로 옮기고 여기서는 매핑만 남긴다).
struct RoomDetailLocation: Identifiable, Equatable {
    let id: UUID = UUID()
    let name: String
    let address: String
    /// 코멘트 수 표기 문자열. "999+" 처럼 서버가 잘라 주는 값을 그대로 쓴다.
    let commentCount: String
    /// 카드형에서 나란히 보여줄 사진 개수. 이미지 에셋이 없어 개수만 유지한다.
    let photoCount: Int
}

/// 방 헤더에 들어가는 방 정보.
struct RoomDetailRoom: Equatable {
    let title: String
    let memo: String
    /// 장소 수 표기 문자열("999+개").
    let locationCountText: String
    /// 참여자 수 — 아바타 그룹에 몇 명까지 겹쳐 그릴지에 쓴다.
    let memberCount: Int
}

// MARK: - 정렬 / 보기 모드

/// 툴바 좌측 드롭다운의 정렬 기준. Figma `004-1-3 full` 드롭다운 항목 순서 그대로.
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
    /// 좌측 썸네일 1장 + 텍스트 (`004-1-3 full_리스트형`)
    case list
    /// 텍스트 + 썸네일 2장 (`004-1-3 full_카드형`)
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
    /// Figma 시안의 헤더 값.
    static let sample = RoomDetailRoom(
        title: "가나다라마바사아자차카타파하다",
        memo: "memo",
        locationCountText: "999+개",
        memberCount: 1
    )
}

extension RoomDetailLocation {
    /// Figma 시안의 카드 값. 서버 연동 전 화면 확인용.
    static let samples: [RoomDetailLocation] = (0..<8).map { _ in
        RoomDetailLocation(
            name: "레이어스튜디오 10",
            address: "서울 성동구 상원4길 10",
            commentCount: "999+",
            photoCount: 2
        )
    }
}
