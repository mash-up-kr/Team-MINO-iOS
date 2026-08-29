import Foundation
import Testing
import Domain
@testable import PlaceDetailUI

struct PlaceDetailPlaceTests {
    private let sharer = MemberProfile(id: MemberID("user-0002"), nickname: "지훈", avatarID: 2)

    private func pin(images: [URL] = [], createdBy: MemberProfile? = nil) -> Pin {
        PinFixture.pin(
            id: PinID("p1"),
            roomID: "r1",
            category: .popularAmongFriends,
            title: "레이어스튜디오 10",
            address: "서울 성동구 상원4길 10",
            images: images,
            createdBy: createdBy,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    @Test("핀의 사진·저장자·큐레이션 라벨을 그대로 싣는다")
    func carriesDisplayFields() {
        let photos = [
            URL(string: "https://example.com/1.jpg")!,
            URL(string: "https://example.com/2.jpg")!,
        ]
        let place = PlaceDetailPlace(from: pin(images: photos, createdBy: sharer))

        #expect(place.photos == photos)
        #expect(place.sharer == sharer)
        #expect(place.category == .popularAmongFriends)
    }

    @Test("서버가 저장자를 주지 않으면 nil 로 남아 익명으로 그려진다")
    func allowsMissingSharer() {
        #expect(PlaceDetailPlace(from: pin()).sharer == nil)
    }

    @Test("사진이 없는 핀은 빈 배열이라 캐러셀을 그릴 것이 없다")
    func allowsNoPhotos() {
        #expect(PlaceDetailPlace(from: pin()).photos.isEmpty)
    }
}
