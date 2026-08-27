import Domain
import Foundation

struct PlaceDetailPlace: Equatable {
    let name: String
    let address: String
    let savedDays: Int
    let photoCount: Int
}

extension PlaceDetailPlace {
    init(from pin: Pin, now: Date) {
        self.init(
            name: pin.place.name,
            address: pin.place.address,
            savedDays: PlaceDetailSaveAge.days(since: pin.createdAt, now: now),
            photoCount: pin.images.count
        )
    }
}

enum PlaceDetailSaveAge {
    static func days(since createdAt: Date, now: Date, calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: createdAt)
        let to = calendar.startOfDay(for: now)
        let elapsed = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        return max(1, elapsed + 1)
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
        savedDays: 30,
        photoCount: 2
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
