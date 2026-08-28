import Domain
import Foundation
import Testing
@testable import FeatureArchive

/// 장소 카드가 사진을 어떻게 줄여 쓰는지 — "첫 장" 은 기획 011-1 ② 가 못박은 규칙이라 고정한다.
struct RoomDetailLocationTests {
    private let photos = (0..<3).compactMap { URL(string: "https://example.com/\($0).jpg") }

    @Test("대표 썸네일은 사진 중 첫 장이다")
    func thumbnailIsFirstPhoto() {
        let location = location(photos: photos)
        #expect(location.thumbnail == photos.first)
    }

    @Test("사진이 없으면 대표 썸네일도 없다 — 화면은 자리표로 떨어진다")
    func thumbnailIsNilWithoutPhotos() {
        #expect(location(photos: []).thumbnail == nil)
    }

    @Test("사진 수는 배열에서 센다 — 따로 든 개수와 어긋나지 않는다")
    func photoCountFollowsPhotos() {
        #expect(location(photos: photos).photoCount == 3)
        #expect(location(photos: []).photoCount == 0)
    }

    @Test("Pin 의 사진이 그대로 실려 온다")
    func mapsPinImages() {
        let pin = PinFixture.pin(
            id: PinID("p1"), roomID: "r1", category: .worthVisiting,
            title: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
            images: photos, createdAt: Date(timeIntervalSince1970: 0)
        )
        #expect(RoomDetailLocation(from: pin).photos == photos)
    }

    private func location(photos: [URL]) -> RoomDetailLocation {
        RoomDetailLocation(
            id: "p1", name: "레이어스튜디오 10", address: "서울 성동구 상원4길 10",
            commentCount: 0, photos: photos
        )
    }
}
