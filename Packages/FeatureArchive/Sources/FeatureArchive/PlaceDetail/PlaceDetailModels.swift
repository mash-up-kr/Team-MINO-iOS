import Domain
import Foundation

struct PlaceDetailPlace: Equatable {
    let name: String
    let address: String
    /// 출처 게시글의 사진. 없을 수 있다 — 그러면 캐러셀 자체를 그리지 않는다.
    let photos: [URL]
    /// 이 장소를 저장한 사람. 서버가 주지 않으면 nil 이라 익명 아바타로 그린다.
    let sharer: MemberProfile?
    /// 홈 카드와 같은 큐레이션 라벨. 헤더 뱃지가 이걸 그린다.
    let category: PinCategory
}

extension PlaceDetailPlace {
    init(from pin: Pin) {
        self.init(
            name: pin.place.name,
            address: pin.place.address,
            photos: pin.images,
            sharer: pin.createdBy,
            category: pin.category
        )
    }
}

struct PlaceDetailComment: Identifiable, Equatable {
    let id: String
    /// 작성자 신원. 닉네임 문자열이 아니라 프로필째 든다 — 표시 이름(``MemberProfile/nickname``)과
    /// 소유 판정에 쓰는 식별자가 한 값에서 나와야 서로 어긋나지 않는다.
    let author: MemberProfile
    let body: String

    static let bodyLimit = 200
}

extension PlaceDetailComment {
    /// 이 코멘트를 지울 수 있는 사람인가 — 닉네임이 아니라 **식별자**로만 판정한다.
    /// 닉네임으로 보면 남이 "나" 로 개명하는 순간 그 사람 코멘트에 내 삭제 버튼이 붙는다.
    ///
    /// `viewer` 가 nil(내 신원을 아직·끝내 못 가져옴)이면 항상 false — 모르면 못 지우는 쪽으로 실패한다.
    func isWritten(by viewer: MemberID?) -> Bool {
        author.id == viewer
    }
}

/// ⑭ 코멘트 삭제 확인 다이얼로그가 겨냥한 코멘트. nil 이면 다이얼로그가 닫혀 있다.
///
/// 열림 여부를 Bool 로 두지 않는다 — "열렸다" 와 "무엇을 지운다" 가 갈라지면 확인을 누른 순간
/// 엉뚱한 줄이 사라진다. 방 상세의 장소 삭제(``RoomDetailDeletion``)와 같은 모양이다.
struct PlaceDetailCommentDeletion: Equatable, Identifiable {
    let commentID: PlaceDetailComment.ID

    var id: PlaceDetailComment.ID { commentID }
}

extension PlaceDetailPlace {
    static let sample = PlaceDetailPlace(
        name: "레이어스튜디오 10",
        address: "서울 성동구 상원4길 10",
        photos: [
            URL(string: "https://picsum.photos/seed/gguk-0-0/800/600")!,
            URL(string: "https://picsum.photos/seed/gguk-0-1/800/600")!,
        ],
        sharer: MemberProfile(id: MemberID("user-0003"), nickname: "서연", avatarID: 3),
        category: .popularAmongFriends
    )
}

extension PlaceDetailComment {
    /// 프리뷰용 표본. `c2` 만 앱이 목업으로 물려 둔 현재 사용자(`user-0001`)라, 프리뷰에서
    /// 케밥이 그 한 줄에만 붙는다.
    static let samples: [PlaceDetailComment] = [
        PlaceDetailComment(
            id: "c1",
            author: MemberProfile(id: MemberID("user-0003"), nickname: "서연", avatarID: 3),
            body: "친구가 남긴 코멘트입니다."
        ),
        PlaceDetailComment(
            id: "c2",
            author: MemberProfile(id: MemberID("user-0001"), nickname: "나", avatarID: 1),
            body: String(repeating: "친구가 남긴 코멘트입니다.", count: 6)
        ),
        PlaceDetailComment(
            id: "c3",
            author: MemberProfile(id: MemberID("user-0004"), nickname: "에린", avatarID: 4),
            body: String(repeating: "친구가 남긴 코멘트입니다.", count: 12)
        ),
    ]
}

enum PlaceDetailExternalMap {
    static func url(forAddress address: String) -> URL? {
        let query = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty,
              let encoded = query.addingPercentEncoding(withAllowedCharacters: .alphanumerics)
        else { return nil }
        return URL(string: "https://maps.apple.com/?q=\(encoded)")
    }
}
