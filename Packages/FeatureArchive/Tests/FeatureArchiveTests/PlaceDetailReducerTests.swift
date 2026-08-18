import Foundation
import Testing
import Domain
import MVITestSupport
@testable import FeatureArchive

private let fixtureNow = Date(timeIntervalSince1970: 1_700_000_000)

private let fixturePin = Pin(
    id: PinID("p1"),
    roomID: "r1",
    category: .worthVisiting,
    title: "레이어스튜디오 10",
    address: "서울 성동구 상원4길 10",
    createdAt: fixtureNow.addingTimeInterval(-29 * 86_400)
)

@MainActor
struct PlaceDetailReducerTests {
    private func makeStore() -> TestStore<PlaceDetailState, PlaceDetailAction, PlaceDetailNav> {
        var remaining = ["c1", "c2", "c3"]
        return TestStore(
            PlaceDetailState(place: PlaceDetailPlace(from: fixturePin, now: fixtureNow)),
            reduce: placeDetailReducer(pin: fixturePin, makeCommentID: { remaining.removeFirst() })
        )
    }

    @Test("L1 — submitComment 는 내 코멘트를 목록 끝에 붙인다")
    func submitComment() async {
        let store = makeStore()
        await store.send(.submitComment("좋았어요")) {
            $0.comments = [PlaceDetailComment(id: "c1", author: "나", body: "좋았어요")]
        }
        store.finish()
    }

    @Test("L1 — 앞뒤 공백은 잘라내고, 공백뿐이면 아무것도 추가하지 않는다")
    func submitComment_trimsAndIgnoresBlank() async {
        let store = makeStore()
        await store.send(.submitComment("  좋았어요  ")) {
            $0.comments = [PlaceDetailComment(id: "c1", author: "나", body: "좋았어요")]
        }
        await store.send(.submitComment("   "))
        store.finish()
    }

    @Test("L1 — 200자를 넘는 코멘트는 잘라 저장한다")
    func submitComment_clampsToLimit() async {
        let store = makeStore()
        let clamped = String(repeating: "가", count: PlaceDetailComment.bodyLimit)
        await store.send(.submitComment(String(repeating: "가", count: 250))) {
            $0.comments = [PlaceDetailComment(id: "c1", author: "나", body: clamped)]
        }
        store.finish()
    }

    @Test("L1 — tapClose 는 close 로 navigate 한다")
    func tapClose() async {
        let store = makeStore()
        await store.send(.tapClose)
        store.receiveNavigation(.close)
        store.finish()
    }

    @Test("L1 — tapShare 는 이 장소를 실어 navigate 한다")
    func tapShare() async {
        let store = makeStore()
        await store.send(.tapShare)
        store.receiveNavigation(.share(RoomDetailLocation(from: fixturePin)))
        store.finish()
    }
}

struct PlaceDetailExternalMapTests {
    @Test("주소를 검색어로 실은 지도 URL 을 만든다")
    func buildsSearchURL() {
        let url = PlaceDetailExternalMap.url(forAddress: "서울 성동구 상원4길 10")
        #expect(url?.absoluteString == "https://maps.apple.com/?q=%EC%84%9C%EC%9A%B8%20%EC%84%B1%EB%8F%99%EA%B5%AC%20%EC%83%81%EC%9B%904%EA%B8%B8%2010")
    }

    @Test("주소가 비어 있으면 URL 을 만들지 않는다")
    func rejectsBlankAddress() {
        #expect(PlaceDetailExternalMap.url(forAddress: "   ") == nil)
    }
}
