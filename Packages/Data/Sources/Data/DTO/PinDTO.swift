import Domain
import Foundation

/// API 스키마와 결합되는 DTO. internal 로 닫아 Domain 에 노출되지 않게 한다.
///
/// 목록(`GET /api/v1/pins`)·상세(`GET /api/v1/pins/{pinId}`)·홈 카드(`GET /api/v1/rooms/{roomId}/cards`)가
/// 거의 같은 모양이지만 **타입을 합치지 않는다** — 카드에만 `labelGroup` 이 있고 상세에만
/// `sourceUrl` 이 있어서, 하나로 합치면 두 필드가 다 옵셔널이 되어 "이 응답엔 원래 없다" 와
/// "서버가 빠뜨렸다" 가 구분되지 않는다.

/// 방에 저장된 장소 한 건 (`GET /api/v1/pins`).
struct PinDTO: Decodable {
    let id: String
    let roomId: String
    let place: PinPlaceDTO
    /// 게시물 이미지. 스펙상 항상 배열이지만 서버가 키를 빠뜨려도 목록이 통째로 깨지지 않게 옵셔널로 받는다.
    let images: [String]?
    let createdBy: PinAuthorDTO?
    let createdAt: Date
}

/// 장소(핀) 상세 (`GET /api/v1/pins/{pinId}`). 목록에 실리지 않는 출처 링크가 함께 온다.
struct PinDetailDTO: Decodable {
    let id: String
    let roomId: String
    let place: PinPlaceDTO
    let images: [String]?
    let createdBy: PinAuthorDTO?
    let createdAt: Date
    /// 이 장소가 어디서 왔는지(인스타그램 게시물 등). 출처 없이 만들어진 핀은 null.
    let sourceUrl: String?
}

/// 홈 카드 덱 응답 (`GET /api/v1/rooms/{roomId}/cards`). **`data` 가 배열이 아니라 객체다** —
/// 서버가 홈 헤더용 방 메타(`room`)를 함께 실으면서 카드가 `cards` 한 겹 안으로 들어갔다.
///
/// 그 `room`(id·type·name·color)은 **받지 않는다**. 홈은 방 우선 순회와 방 선택 시트 때문에
/// 어차피 방 목록(`GET /api/v1/rooms`)을 먼저 받고 그 네 필드를 이미 들고 있어서
/// (헤더 뱃지·마스코트가 읽는 `HomeState.currentRoom` 이 그것이다), 여기서 또 읽어도
/// 줄일 수 있는 요청이 없다. 선언하지 않으면 서버가 `room` 을 빼도 덱이 깨지지 않는다 —
/// 스웨거가 이 응답에는 `required` 를 적어 두지 않아 필수인지 아닌지도 알 수 없다.
struct PinCardDeckDTO: Decodable {
    let cards: [PinCardDTO]
}

/// 홈 카드 한 장 (`GET /api/v1/rooms/{roomId}/cards`). 서버가 붙여 준 큐레이션 라벨이 함께 온다.
struct PinCardDTO: Decodable {
    let id: String
    let roomId: String
    let place: PinPlaceDTO
    let images: [String]?
    let createdBy: PinAuthorDTO?
    let createdAt: Date
    let labelGroup: String
}

/// 장소 정보. 서버는 `places` 컬럼 전체를 주지만 화면이 쓰는 것만 받는다.
struct PinPlaceDTO: Decodable {
    let id: String
    let name: String
    let address: String
    let lat: Double
    let lng: Double
    /// 업종(카페·음식점 등). provider 별 정규화가 미확정이라 서버도 원문을 통과시킨다.
    let category: String?
    /// 외부 지도 서비스의 장소 상세 URL.
    let mapUrl: String?
}

/// 이 장소를 저장한 멤버. 계정이 지워졌거나 저장자를 모르는 핀은 null 로 온다.
struct PinAuthorDTO: Decodable {
    let userId: String
    let nickname: String
    /// 스펙상 nullable — 아바타를 아직 안 고른 계정이 있다. 방 응답과 같은 ``AvatarDTO`` 를 재사용한다.
    let avatar: AvatarDTO?
}

// MARK: - 경계(Data → Domain) 변환

extension PinDTO {
    /// - Parameter category: 목록 응답에는 큐레이션 라벨이 없다. 라벨은 홈 카드에만 붙는 개념이라
    ///   서버가 목록에 싣지 않으며, 여기서는 기본값(`가볼 만한 곳`)으로 채운다 —
    ///   방 상세·지도는 라벨을 그리지 않으므로 화면에 드러나지 않는다.
    func toDomain(category: PinCategory = .worthVisiting) -> Pin {
        Pin(
            id: PinID(id),
            roomID: roomId,
            place: place.toDomain(),
            images: PinImageMapper.urls(images),
            createdBy: createdBy?.toDomain(),
            // ⚠️ 서버가 코멘트 수를 목록·카드 어느 응답에도 싣지 않는다. 0 으로 두면 004-1 ⑥
            // "코멘트순"이 저장 시각순과 같아지고 카드의 "코멘트 N" 도 0 으로 고정된다.
            // 응답에 필드가 생기면 여기만 갈아끼운다.
            commentCount: 0,
            category: category,
            createdAt: createdAt
        )
    }
}

extension PinDetailDTO {
    func toDomain() -> PinDetail {
        PinDetail(
            pin: Pin(
                id: PinID(id),
                roomID: roomId,
                place: place.toDomain(),
                images: PinImageMapper.urls(images),
                createdBy: createdBy?.toDomain(),
                commentCount: 0,   // ``PinDTO/toDomain(category:)`` 의 주석과 같은 이유
                category: .worthVisiting,
                createdAt: createdAt
            ),
            sourceURL: sourceUrl.flatMap(URL.init(string:))
        )
    }
}

extension PinCardDTO {
    func toDomain() -> Pin {
        Pin(
            id: PinID(id),
            roomID: roomId,
            place: place.toDomain(),
            images: PinImageMapper.urls(images),
            createdBy: createdBy?.toDomain(),
            commentCount: 0,   // ``PinDTO/toDomain(category:)`` 의 주석과 같은 이유
            category: Self.category(from: labelGroup),
            createdAt: createdAt
        )
    }

    /// 서버 라벨 → 카드 뱃지. 두 어휘는 이름이 다르지만 **뱃지 문구로 1:1 대응한다**:
    /// `worthVisiting`=가볼 만한 곳 / `manyViews`=친구들이 많이 본 곳 /
    /// `manySaves`=여럿이 저장한 곳 / `manyComments`=이야기 많은 곳.
    ///
    /// 모르는 라벨(서버가 우리보다 앞서 나간 경우)은 `가볼 만한 곳` 으로 떨어뜨린다 —
    /// 카드 하나 때문에 덱 전체의 디코딩을 깨뜨리는 것보다 낫다.
    private static func category(from labelGroup: String) -> PinCategory {
        switch labelGroup {
        case "worthVisiting": .worthVisiting
        case "manyViews": .popularAmongFriends
        case "manySaves": .savedByMany
        case "manyComments": .manyStories
        default: .worthVisiting
        }
    }
}

extension PinPlaceDTO {
    func toDomain() -> Place {
        Place(
            id: PlaceID(id),
            name: name,
            address: address,
            coordinate: Coordinate(latitude: lat, longitude: lng),
            category: category,
            mapURL: mapUrl.flatMap(URL.init(string:))
        )
    }
}

extension PinAuthorDTO {
    func toDomain() -> MemberProfile {
        MemberProfile(
            id: MemberID(userId),
            nickname: nickname,
            // 모르는 색은 "아바타 없음" 으로 떨군다 — 목록 전체의 디코딩을 깨뜨리는 것보다 낫다
            // (`ProfileDTO.toDomain()`·`RoomMemberDTO.toDomain()` 과 같은 판단).
            avatarColor: avatar?.color.flatMap(AvatarColor.init(rawValue:))
        )
    }
}

/// 사진 URL 매핑. 세 응답이 같은 규칙을 쓰므로 한 곳에 둔다.
enum PinImageMapper {
    /// 파싱되지 않는 문자열은 **그 한 장만** 버린다. 통째로 비우면 사진이 있는 장소가 없는 것처럼 보인다.
    static func urls(_ raw: [String]?) -> [URL] {
        (raw ?? []).compactMap(URL.init(string:))
    }
}

// MARK: - 요청

/// 「다른 방에 공유」 요청 본문 (`POST /api/v1/pins/{pinId}/duplicate`).
struct DuplicatePinRequestDTO: Encodable, Sendable {
    /// 최소 1개(스펙). 화면이 "방을 하나라도 골라야 저장 활성"을 지키므로 빈 배열은 오지 않는다.
    let roomIds: [String]
}

/// `POST /api/v1/rooms/pins` 요청 본문.
/// 응답 DTO 는 없다 — 202 에 본문이 없다(`PinAPI.create` 참조).
struct CreatePinRequestDTO: Encodable, Sendable {
    let url: URL
    /// 최소 1개(스펙). 화면이 "방을 하나라도 골라야 저장 활성"을 지키므로 빈 배열은 오지 않는다.
    let roomIds: [String]
}
