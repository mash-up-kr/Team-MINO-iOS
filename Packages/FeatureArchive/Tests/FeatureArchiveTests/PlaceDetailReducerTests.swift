import Foundation
import Testing
import Domain
import MVITestSupport
@testable import FeatureArchive

private let fixtureNow = Date(timeIntervalSince1970: 1_700_000_000)

private let fixturePin = PinFixture.pin(
    id: PinID("p1"),
    roomID: "r1",
    category: .worthVisiting,
    title: "레이어스튜디오 10",
    address: "서울 성동구 상원4길 10",
    createdAt: fixtureNow.addingTimeInterval(-29 * 86_400)
)

private let fixtureSourceURL = URL(string: "https://www.instagram.com/p/mock-layer10/")!

/// 핀 단독 조회를 즉답시키는 스텁 — 출처가 있는 핀·없는 핀·조회 실패·취소를 골라 재생한다.
private struct StubFetchPinDetail: FetchPinDetailUseCase {
    enum Outcome: Sendable {
        case source(URL?)
        case failure(DomainError)
        case cancelled
    }

    let outcome: Outcome

    func execute(pinID: PinID) async throws -> PinDetail {
        switch outcome {
        case .source(let url): return PinDetail(pin: fixturePin, sourceURL: url)
        case .failure(let error): throw error
        case .cancelled: throw CancellationError()
        }
    }
}

@MainActor
struct PlaceDetailReducerTests {
    private func makeStore(
        source: StubFetchPinDetail.Outcome = .source(fixtureSourceURL)
    ) -> TestStore<PlaceDetailState, PlaceDetailAction, PlaceDetailNav> {
        var remaining = ["c1", "c2", "c3"]
        return TestStore(
            PlaceDetailState(place: PlaceDetailPlace(from: fixturePin, now: fixtureNow)),
            reduce: placeDetailReducer(
                useCase: StubFetchPinDetail(outcome: source),
                pin: fixturePin,
                makeCommentID: { remaining.removeFirst() }
            )
        )
    }

    @Test("L2 — load 는 출처 링크를 받아 원문보기를 열 수 있게 만든다")
    func loadSource() async {
        let store = makeStore(source: .source(fixtureSourceURL))
        await store.send(.load) { $0.isLoadingSource = true }
        await store.receive(.sourceLoaded(fixtureSourceURL)) {
            $0.sourceURL = fixtureSourceURL
            $0.isLoadingSource = false
        }
        store.finish()
    }

    @Test("L2 — 출처가 없는 핀은 sourceURL 이 nil 로 남는다")
    func loadSource_absent() async {
        let store = makeStore(source: .source(nil))
        await store.send(.load) { $0.isLoadingSource = true }
        await store.receive(.sourceLoaded(nil)) { $0.isLoadingSource = false }
        #expect(store.currentState.sourceURL == nil)
        store.finish()
    }

    @Test("L2 — 조회에 실패해도 오류를 화면에 흘리지 않고 비활성으로 남긴다")
    func loadSource_failure() async {
        let store = makeStore(source: .failure(.unknown))
        await store.send(.load) { $0.isLoadingSource = true }
        await store.receive(.sourceLoadFailed(.unknown)) { $0.isLoadingSource = false }
        #expect(store.currentState.sourceURL == nil)
        store.finish()
    }

    @Test("L2 — 취소는 실패가 아니라 결과가 필요 없어진 것이라 아무 action 도 돌아오지 않는다")
    func loadSource_cancelled() async {
        let store = makeStore(source: .cancelled)
        await store.send(.load) { $0.isLoadingSource = true }
        store.finish()
    }

    @Test("L1 — 조회가 진행 중이면 load 를 다시 받아도 중복 조회하지 않는다")
    func load_isIdempotentWhileLoading() async {
        let store = makeStore(source: .cancelled)
        await store.send(.load) { $0.isLoadingSource = true }
        await store.send(.load)
        store.finish()
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

struct PlaceDetailSaveAgeTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ iso: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: iso)!
    }

    @Test("저장한 당일은 1일째")
    func sameDay() {
        let days = PlaceDetailSaveAge.days(
            since: date("2026-08-16 09:00"), now: date("2026-08-16 23:00"), calendar: calendar
        )
        #expect(days == 1)
    }

    @Test("자정을 넘기면 24시간이 안 지나도 2일째")
    func nextCalendarDay() {
        let days = PlaceDetailSaveAge.days(
            since: date("2026-08-15 23:00"), now: date("2026-08-16 01:00"), calendar: calendar
        )
        #expect(days == 2)
    }

    @Test("29일 전 저장이면 30일째")
    func thirtiethDay() {
        let days = PlaceDetailSaveAge.days(
            since: date("2026-07-18 12:00"), now: date("2026-08-16 12:00"), calendar: calendar
        )
        #expect(days == 30)
    }

    @Test("기기 시계가 뒤로 가 있어도 1일째 아래로는 내려가지 않는다")
    func futureDateClamps() {
        let days = PlaceDetailSaveAge.days(
            since: date("2026-08-20 12:00"), now: date("2026-08-16 12:00"), calendar: calendar
        )
        #expect(days == 1)
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
