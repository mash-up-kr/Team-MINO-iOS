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

    @Test("핀의 사진·저장자를 그대로 싣는다")
    func carriesDisplayFields() {
        let photos = [
            URL(string: "https://example.com/1.jpg")!,
            URL(string: "https://example.com/2.jpg")!,
        ]
        let place = PlaceDetailPlace(from: pin(images: photos, createdBy: sharer), label: nil)

        #expect(place.photos == photos)
        #expect(place.sharer == sharer)
    }

    // 002-1-1 ① — 라벨은 진입 경로가 정한다. 핀이 늘 `category` 를 들고 있어서, 이 규칙이
    // 깨지는 방식은 "핀에서 자동으로 꺼내 쓰는 것" 하나뿐이다. 두 방향을 다 못 박는다.
    @Test("홈 카드로 들어오면 그 카드의 라벨을 그대로 단다")
    func carriesLabelFromHome() {
        let place = PlaceDetailPlace(from: pin(), label: .popularAmongFriends)
        #expect(place.label == .popularAmongFriends)
    }

    @Test("홈 이외 경로(저장 탭·지도·알림)로 들어오면 핀이 라벨을 들고 있어도 노출하지 않는다")
    func omitsLabelOutsideHome() {
        let source = pin()
        #expect(source.category == .popularAmongFriends)   // 핀 자신은 라벨을 갖고 있다
        #expect(PlaceDetailPlace(from: source, label: nil).label == nil)
    }

    @Test("서버가 저장자를 주지 않으면 nil 로 남아 익명으로 그려진다")
    func allowsMissingSharer() {
        #expect(PlaceDetailPlace(from: pin(), label: nil).sharer == nil)
    }

    @Test("사진이 없는 핀은 빈 배열이라 캐러셀을 그릴 것이 없다")
    func allowsNoPhotos() {
        #expect(PlaceDetailPlace(from: pin(), label: nil).photos.isEmpty)
    }
}
