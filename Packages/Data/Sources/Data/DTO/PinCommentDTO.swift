import Domain
import Foundation

/// `GET|POST /api/v1/pins/{pinId}/comments` 의 `data` 항목.
/// envelope(`{"data": …}`·`pagination`)은 `HTTPClient` 가 벗기므로 래퍼 타입을 만들지 않는다.
///
/// internal 로 닫아 Domain 에 노출되지 않게 한다.
struct PinCommentDTO: Decodable {
    let id: String
    /// 서버 필드명은 `content` 다. Domain 은 같은 값을 ``PinComment/body`` 로 부른다 —
    /// 어휘를 잇는 자리는 아래 `toDomain(pinID:)` 하나다.
    let content: String
    let createdAt: Date
    let author: PinCommentAuthorDTO
    /// 이 코멘트를 **지울 수 있는가**(서버 판정).
    ///
    /// ⚠️ **디코딩만 하고 Domain 으로 옮기지 않는다.** 화면의 삭제 아이콘은 이미
    /// ``PinComment/isWritten(by:)`` 로, 즉 `CurrentMember` 의 식별자와 작성자를 맞춰 판정한다
    /// (기획 005-1 ⑭). 여기서 `canDelete` 를 함께 실으면 같은 질문에 답이 둘이 되고, 두 값이
    /// 어긋나는 순간(캐시된 목록 + 갱신된 신원) 어느 쪽을 믿을지가 화면마다 갈린다.
    ///
    /// 필드를 아예 빼지 않고 받아 두는 이유: 스펙상 **필수**라 옵셔널로 두면 계약이 바뀌어
    /// 사라져도 눈치채지 못한다. 서버가 "작성자 = 지울 수 있는 사람" 이 아닌 규칙(방장 삭제 등)을
    /// 들이는 날, 이 자리가 그것을 Domain 으로 올릴 지점이다.
    ///
    /// 최종 판정은 어차피 서버가 한다 — 클라이언트가 통과시켜도 삭제 요청은 403 으로 거절된다.
    let canDelete: Bool
}

/// 코멘트 작성자. `id`·`nickname`·`avatar` 셋 다 스펙상 필수다.
///
/// ``PinAuthorDTO``(핀 저장자)와 합치지 않는다 — 그쪽 식별자 필드명은 `userId` 이고 이쪽은 `id` 라,
/// 한 타입으로 묶으려면 둘 중 하나에 `CodingKeys` 로 별칭을 달아야 한다. 서버가 두 응답을 따로
/// 정의하고 있어 한쪽이 바뀌어도 다른 쪽이 따라가지 않는다. 아바타(``AvatarDTO``)는 공유한다.
struct PinCommentAuthorDTO: Decodable {
    let id: String
    let nickname: String
    /// 스펙상 nullable — 아바타를 아직 안 고른 계정이 있다.
    let avatar: AvatarDTO?
}

// MARK: - 경계(Data → Domain) 변환

extension PinCommentDTO {
    /// - Parameter pinID: 응답 항목에 핀 식별자가 없다. 어느 핀의 코멘트를 물었는지는 **요청이**
    ///   알고 있으므로 호출부가 되돌려 준다 — 서버가 안 준 값을 지어내는 게 아니다.
    func toDomain(pinID: PinID) -> PinComment {
        PinComment(
            id: PinCommentID(id),
            pinID: pinID,
            author: author.toDomain(),
            body: content,
            createdAt: createdAt
        )
    }
}

extension PinCommentAuthorDTO {
    func toDomain() -> MemberProfile {
        MemberProfile(
            id: MemberID(id),
            nickname: nickname,
            // 모르는 색은 "아바타 없음" 으로 떨군다 — 코멘트 목록 전체의 디코딩을 깨뜨리는 것보다
            // 낫다 (`ProfileDTO.toDomain()`·`PinAuthorDTO.toDomain()` 과 같은 판단).
            avatarColor: avatar?.color.flatMap(AvatarColor.init(rawValue:))
        )
    }
}

// MARK: - 요청

/// 코멘트 등록 요청 본문 (`POST /api/v1/pins/{pinId}/comments`).
///
/// 키는 `content` 다 — Domain 의 `body` 를 그대로 보내면 서버가 400(`VALIDATION_ERROR`)으로 거절한다.
/// 앞뒤 공백 제거와 200자 절단은 여기 오기 전에 `DefaultPostPinCommentUseCase` 가 끝낸다.
struct PostPinCommentRequestDTO: Encodable, Sendable {
    let content: String
}
