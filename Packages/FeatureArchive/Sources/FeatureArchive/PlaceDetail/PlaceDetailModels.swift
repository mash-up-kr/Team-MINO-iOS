import Domain
import Foundation

struct PlaceDetailPlace: Equatable {
    let name: String
    let address: String
    let savedDays: Int
    let photoCount: Int
}

extension PlaceDetailPlace {
    private static let placeholderPhotoCount = 2

    init(from pin: Pin, now: Date) {
        self.init(
            name: pin.title,
            address: pin.address,
            savedDays: pin.savedDays(asOf: now),
            photoCount: Self.placeholderPhotoCount
        )
    }
}

extension PlaceDetailPlace {
    static let sample = PlaceDetailPlace(
        name: "레이어스튜디오 10",
        address: "서울 성동구 상원4길 10",
        savedDays: 30,
        photoCount: 2
    )
}

extension Comment {
    /// #Preview 전용 픽스처 — 강제 언래핑은 상수 리터럴이라 안전하다(최장 156자 < maxLength).
    static let samples: [Comment] = [
        Comment(id: CommentID("c1"), author: "서연", body: CommentBody("친구가 남긴 코멘트입니다.")!),
        Comment(
            id: CommentID("c2"),
            author: "태윤",
            body: CommentBody(String(repeating: "친구가 남긴 코멘트입니다.", count: 6))!
        ),
        Comment(
            id: CommentID("c3"),
            author: "에린",
            body: CommentBody(String(repeating: "친구가 남긴 코멘트입니다.", count: 12))!
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
