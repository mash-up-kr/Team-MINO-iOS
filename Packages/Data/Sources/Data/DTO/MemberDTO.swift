import Foundation
import Domain

/// API 스키마와 결합되는 DTO. internal 로 닫아 Domain 에 노출되지 않게 한다.
struct MemberDTO: Decodable {
    let id: String
    let name: String
    let email: String?
}

extension MemberDTO {
    /// 경계(Data → Domain) 변환. DTO 를 Entity 로 매핑한다.
    func toDomain() -> Member {
        Member(id: MemberID(id), name: name, email: email)
    }
}
