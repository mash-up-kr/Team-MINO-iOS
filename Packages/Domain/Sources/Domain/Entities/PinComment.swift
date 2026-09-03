import Foundation

/// 방에 저장된 장소(``Pin``) 한 건에 달린 코멘트.
///
/// 어느 핀에 달렸는지는 식별자로만 가리킨다(`pinID`) — 코멘트는 핀 aggregate 안에 들어가지
/// 않는다. 목록·등록·삭제가 핀을 읽지 않고도 일어나고, 핀에 배열로 매달면 코멘트 한 줄을
/// 지울 때마다 핀 전체를 다시 써야 한다.
///
/// 이름이 `Comment` 가 아닌 이유는 둘이다. (1) 코멘트가 붙는 대상은 여러 방이 공유하는
/// ``Place`` 가 아니라 **방 안의 그 장소**(핀)다 — 같은 카페라도 방마다 코멘트가 따로다.
/// (2) `Comment` 는 Swift Testing 의 타입과 겹쳐, `Testing` 을 함께 import 하는 테스트에서
/// 이름이 모호해진다.
///
/// 프레임워크에 의존하지 않는 순수 value type 이며 Codable 을 준수하지 않는다(API 스키마와 결합 방지).
public struct PinComment: Equatable, Identifiable, Sendable {
    public let id: PinCommentID
    public let pinID: PinID
    /// 작성자 신원. 닉네임 문자열이 아니라 프로필째 든다 — 표시 이름(``MemberProfile/nickname``)과
    /// 소유 판정에 쓰는 식별자가 한 값에서 나와야 서로 어긋나지 않는다.
    public let author: MemberProfile
    public let body: String
    public let createdAt: Date

    /// 본문 상한(기획 005-1 — 입력창의 글자수 카운터가 세는 값).
    /// 서버가 거절하는 길이라 화면의 카운터와 등록 경로가 **같은 값**을 봐야 한다.
    public static let bodyLimit = 200

    public init(
        id: PinCommentID,
        pinID: PinID,
        author: MemberProfile,
        body: String,
        createdAt: Date
    ) {
        self.id = id
        self.pinID = pinID
        self.author = author
        self.body = body
        self.createdAt = createdAt
    }
}

extension PinComment {
    /// 이 코멘트를 지울 수 있는 사람인가 — 닉네임이 아니라 **식별자**로만 판정한다.
    /// 닉네임으로 보면 남이 "나" 로 개명하는 순간 그 사람 코멘트에 내 삭제 버튼이 붙는다.
    ///
    /// `viewer` 가 nil(내 신원을 아직·끝내 못 가져옴)이면 항상 false — 모르면 못 지우는 쪽으로 실패한다.
    public func isWritten(by viewer: MemberID?) -> Bool {
        author.id == viewer
    }
}
