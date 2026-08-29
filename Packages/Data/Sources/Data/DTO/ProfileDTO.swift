import Domain
import Foundation

/// `POST /api/v1/users`, `GET|PATCH /api/v1/users/me` 의 `data` 알맹이.
/// envelope(`{"data": …}`)은 `HTTPClient` 가 벗기므로 래퍼 타입을 만들지 않는다.
///
/// internal 로 닫아 Domain 에 노출되지 않게 한다.
struct ProfileDTO: Decodable {
    let id: String
    let nickname: String
    /// 계정에 아바타가 아직 없을 수 있어 옵셔널(스펙상 nullable).
    let avatar: AvatarDTO?
    let createdAt: Date

    func toDomain() -> Profile {
        // 서버가 우리가 모르는 색을 주면 "아바타 없음" 으로 떨어뜨린다 — 화면이 첫 캐릭터로
        // 그리므로, 통째로 디코딩을 깨뜨려 프로필을 못 읽는 것보다 낫다.
        Profile(
            id: id,
            nickname: nickname,
            avatarColor: avatar?.color.flatMap(AvatarColor.init(rawValue:)),
            createdAt: createdAt
        )
    }
}

/// 응답의 아바타. 값은 팔레트 색 이름(`red`·`light_blue` …)이고, 어느 캐릭터 그림인지는
/// 클라이언트가 정한다.
///
/// > ⚠️ **`color` 를 옵셔널로 둔다.** 아바타가 `{ id: Int }` 이던 시절에 가입한 계정은 조회 응답의
/// > `avatar` 에 `color` 가 없다(실측 — `keyNotFound("color")`). 서버에 **회원 삭제 API 가 없어**
/// > 그 계정들을 지울 수단도 없다.
/// >
/// > 아바타는 스펙상 nullable 인 장식 값인데 여기서 디코딩이 깨지면 **프로필 전체를 못 읽어
/// > 앱 진입이 재시도 화면에서 막힌다.** 없으면 없는 대로 받고, 화면은 첫 캐릭터로 그린다.
struct AvatarDTO: Decodable {
    let color: String?
}

/// 요청의 아바타. 응답과 달리 **`color` 를 반드시 싣는다** — 서버가 필수로 요구하므로
/// 옵셔널로 두면 키가 빠진 바디가 조용히 나간다.
struct AvatarRequestDTO: Encodable, Sendable {
    let color: String
}

/// 등록 요청 바디. `nickname`·`avatar` 둘 다 필수(스펙).
struct RegisterProfileRequestDTO: Encodable, Sendable {
    let nickname: String
    let avatar: AvatarRequestDTO
}

/// 수정 요청 바디. 넘긴 항목만 바뀌므로 둘 다 옵셔널이고, nil 이면 키 자체가 빠진다
/// (`JSONEncoder` 는 nil 옵셔널을 인코딩하지 않는다).
struct UpdateProfileRequestDTO: Encodable, Sendable {
    let nickname: String?
    let avatar: AvatarRequestDTO?
}
