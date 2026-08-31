import Domain
import Foundation
import Networking

/// 핀(pin) 엔드포인트. 경로가 방 하위(`rooms/pins`·`rooms/{id}/cards`)인 것도 있지만
/// 다루는 리소스는 핀이라 여기 모은다.
enum PinAPI {
    private static let base = "api/v1/pins"

    /// 홈 카드 피드. 서버가 `sort` 로 후보를 좁힌 뒤 라벨 4종으로 **최대 10장**의 덱을 만든다 —
    /// 정원이 미달인 라벨은 채우지 않으므로 10장보다 짧게 온다. 페이지 파라미터는 없다.
    ///
    /// - Parameter origin: `sort=nearby` 는 좌표가 없으면 400 이다(`VALIDATION_ERROR`).
    ///   다른 기준에서는 좌표를 실어도 무시되므로, 있으면 그냥 함께 보낸다.
    static func cards(roomID: String, filter: PinFilter, origin: Coordinate?) -> Endpoint<[PinCardDTO]> {
        var query = [URLQueryItem(name: "sort", value: sort(for: filter))]
        if let origin {
            query.append(URLQueryItem(name: "lat", value: String(origin.latitude)))
            query.append(URLQueryItem(name: "lng", value: String(origin.longitude)))
        }
        return Endpoint(path: "api/v1/rooms/\(roomID)/cards", queryItems: query)
    }

    /// 방에 저장된 장소 전부. **`page`·`pageSize` 를 둘 다 생략하면 서버가 전체를 준다** —
    /// 방 상세는 클라이언트에서 정렬·필터하므로 전부 받아야 한다(스펙: 지도 전체 보기 보장).
    static func list(roomID: String) -> Endpoint<[PinDTO]> {
        Endpoint(path: base, queryItems: [URLQueryItem(name: "roomId", value: roomID)])
    }

    /// 장소(핀) 상세 — 목록에 없는 출처 링크(`sourceUrl`)가 여기서만 온다.
    static func detail(pinID: String) -> Endpoint<PinDetailDTO> {
        Endpoint(path: "\(base)/\(pinID)")
    }

    /// 장소를 **열어 봤다**고 기록한다 (`POST /api/v1/pins/{pinId}/accesses`).
    ///
    /// append-only 로그라 같은 장소를 여러 번 보내도 된다. 서버는 이 기록을 홈 카드 덱의
    /// 묵힘 계산(꾹 Pick 경과일 초기화)과 클릭수 집계(`친구들이 많이 본 곳` 라벨)에 쓴다.
    static func recordAccess(pinID: String) -> Endpoint<OkResponse> {
        Endpoint(path: "\(base)/\(pinID)/accesses", method: .post)
    }

    /// 인스타그램 링크에서 장소를 추출해 **여러 방에** 핀을 추가한다.
    ///
    /// **202 Accepted 에 본문이 없다** — 서버가 추출을 비동기로 하므로 돌려줄 핀이 아직 없다.
    /// `OkResponse` 로 받는 이유는 클라이언트가 빈 본문을 그 타입일 때만 성공으로 통과시키기
    /// 때문이다(`URLSessionHTTPClient` 의 빈 본문 처리).
    static func create(url: URL, roomIDs: Set<String>) -> Endpoint<OkResponse> {
        Endpoint(
            path: "api/v1/rooms/pins",
            method: .post,
            body: .json(CreatePinRequestDTO(url: url, roomIds: Array(roomIDs)))
        )
    }

    /// 이 장소를 **다른 방에도 담는다** (`POST /api/v1/pins/{pinId}/duplicate`, 기획 011-1).
    ///
    /// 서버가 원본 방·대상 방 멤버십을 모두 검증하고, **대상 방 중 하나라도 같은 장소가 있으면
    /// 409(`DUPLICATE_PIN_IN_ROOM`)로 전체를 거절한다** — 부분 성공이 없다. 화면이 이미 담긴
    /// 방을 체크·비활성으로 빼 두므로(011-1 ④) 정상 경로에서는 나지 않지만, 그 목록이 낡았으면
    /// (다른 기기가 먼저 담음) 통째로 실패한다.
    static func duplicate(pinID: String, roomIDs: Set<String>) -> Endpoint<OkResponse> {
        Endpoint(
            path: "\(base)/\(pinID)/duplicate",
            method: .post,
            body: .json(DuplicatePinRequestDTO(roomIds: Array(roomIDs)))
        )
    }

    /// 조회 기준(필터 칩) → 서버 `sort` 값. 두 어휘를 잇는 자리는 여기 하나다.
    private static func sort(for filter: PinFilter) -> String {
        switch filter {
        case .recommended: "ggukPick"
        case .latest: "latest"
        case .nearby: "nearby"
        }
    }
}
