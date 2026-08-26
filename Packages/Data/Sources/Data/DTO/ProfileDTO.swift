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
        Profile(id: id, nickname: nickname, avatarIndex: avatar?.id, createdAt: createdAt)
    }
}

/// 서버가 아바타를 `{ id: Int }` 로 감싸 주고받는다. id 는 캐릭터 목록에서의 자리(0 부터).
struct AvatarDTO: Codable {
    let id: Int
}

/// 등록 요청 바디. `nickname`·`avatar` 둘 다 필수(스펙).
struct RegisterProfileRequestDTO: Encodable, Sendable {
    let nickname: String
    let avatar: AvatarDTO
}

/// 수정 요청 바디. 넘긴 항목만 바뀌므로 둘 다 옵셔널이고, nil 이면 키 자체가 빠진다
/// (`JSONEncoder` 는 nil 옵셔널을 인코딩하지 않는다).
struct UpdateProfileRequestDTO: Encodable, Sendable {
    let nickname: String?
    let avatar: AvatarDTO?
}
