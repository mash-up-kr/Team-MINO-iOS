import Domain
import Foundation

struct PlaceDetailPlace: Equatable {
    let name: String
    let address: String
    let photoCount: Int
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
            photoCount: pin.images.count,
            sharer: pin.createdBy,
            category: pin.category
        )
    }
}

struct PlaceDetailComment: Identifiable, Equatable {
    let id: String
    let author: String
    let body: String

    static let bodyLimit = 200
    static let localAuthorName = "나"
}

extension PlaceDetailPlace {
    static let sample = PlaceDetailPlace(
        name: "레이어스튜디오 10",
        address: "서울 성동구 상원4길 10",
        photoCount: 2,
        sharer: MemberProfile(id: MemberID("user-0003"), nickname: "서연", avatarID: 3),
        category: .popularAmongFriends
    )
}

extension PlaceDetailComment {
    static let samples: [PlaceDetailComment] = [
        PlaceDetailComment(id: "c1", author: "서연", body: "친구가 남긴 코멘트입니다."),
        PlaceDetailComment(
            id: "c2",
            author: "태윤",
            body: String(repeating: "친구가 남긴 코멘트입니다.", count: 6)
        ),
        PlaceDetailComment(
            id: "c3",
            author: "에린",
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
