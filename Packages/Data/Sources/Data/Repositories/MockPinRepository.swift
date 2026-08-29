import Foundation
import Domain

/// 백엔드 미연결 단계용 `PinRepository`·`PinDetailRepository`·`PinDeletionRepository` 구현.
/// 네트워크 대신 하드코딩 장소 풀로 핀을 합성한다.
/// 추후 네트워크 구현(DTO → `toDomain()` 매핑) 으로 교체하면 이 파일만 지운다.
///
/// 리듀서가 목 데이터를 직접 만들지 않도록(순수성·아키텍처 경계) 여기로 옮겨온 것 —
/// `page` 로 고정 풀을 회전시켜 "더 보기"마다 다른 카드처럼 보이게 한다.
///
/// 목록·상세·삭제를 **한 구현이 겸한다**. 나눠 두면 상세가 목록에 없는 값을 지어내게 되어
/// "목록에서 본 장소"와 "상세에서 보는 장소"가 어긋나고, 삭제는 지운 장소가 다음 조회에서
/// 되살아난다 — 셋이 같은 보관소를 봐야 목업에서도 앞뒤가 맞는다.
public final class MockPinRepository: PinRepository, PinDetailRepository, PinDeletionRepository {
    private let store = MockPinStore()

    public init() {}

    public func pins(rooms: [Room], filter: PinFilter) async throws -> [Pin] {
        var all: [Pin] = []
        for room in rooms {
            all += await makePins(for: room, page: 0, filter: filter)
        }
        return all
    }

    public func pins(room: Room, page: Int, filter: PinFilter) async throws -> [Pin] {
        await makePins(for: room, page: page, filter: filter)
    }

    public func pinDetail(id: PinID) async throws -> PinDetail {
        guard let entry = await store.entry(id: id) else { throw DomainError.unknown }
        return PinDetail(pin: entry.pin, sourceURL: entry.sourceURL)
    }

    /// 삭제 API 가 없어 **지운 id 를 메모리에 들고 있다가** 이후 조회에서 뺀다.
    /// 그냥 성공만 돌려주면 시트를 닫았다 다시 열었을 때 지운 장소가 되살아난다.
    /// 네트워크처럼 잠깐 기다렸다 성공하는 지연은 확인 버튼이 잠기는 걸 실물처럼 보기 위한 것이다.
    ///
    /// 목 핀 id 에는 `page`·`filter` 가 섞여 있어(``makePins``) 같은 장소라도 조회 기준이 다르면
    /// 다른 핀이다. 방 상세에서 지운 장소가 홈의 "최신순" 덱에는 남아 있는 이유 —
    /// 실 API 가 붙으면 서버 id 하나로 통일되면서 사라지는 목 한정 현상이다.
    public func delete(pinID: PinID) async throws {
        try? await Task.sleep(for: .milliseconds(300))
        await store.markDeleted(id: pinID)
    }

    // MARK: - Mock 합성

    private func makePins(for room: Room, page: Int, filter: PinFilter) async -> [Pin] {
        let now = Date.now
        let count = Self.places.count
        // page 마다 풀을 회전시켜 다른 카드처럼 보이게 하고, id 에 page·filter 를 넣어 서로 겹치지 않게 한다.
        let rotated = (0..<count).map { ($0 + page) % count }
        var made: [Pin] = []
        for (i, src) in Self.order(rotated, for: filter).enumerated() {
            let seed = Self.places[src]
            let pin = Pin(
                id: PinID("pin-\(room.id)-\(filter.rawValue)-\(page)-\(i)"),
                roomID: room.id,
                place: Place(
                    id: PlaceID("place-\(src)"),
                    name: seed.name,
                    address: seed.address,
                    coordinate: Coordinate(latitude: seed.latitude, longitude: seed.longitude),
                    category: seed.category
                ),
                images: Self.images(src: src, count: seed.photoCount),
                createdBy: Self.members[src % Self.members.count],
                commentCount: seed.commentCount,
                category: Self.categories[src],
                createdAt: now.addingTimeInterval(Double(-i) * 86400)
            )
            await store.register(pin, sourceURL: seed.sourceURL.flatMap(URL.init(string:)))
            made.append(pin)
        }
        return await store.removingDeleted(made)
    }

    /// 실제 필터링·정렬은 서버 몫이지만, 목에서도 기준마다 순서를 다르게 줘서
    /// 칩을 눌렀을 때 덱이 실제로 바뀌는지 눈으로 확인할 수 있게 한다.
    private static func order(_ indices: [Int], for filter: PinFilter) -> [Int] {
        switch filter {
        case .recommended: indices                                   // 풀 순서 그대로
        case .latest: indices.reversed()                             // 뒤집어서
        case .nearby: Array(indices.dropFirst(count / 2) + indices.prefix(count / 2))   // 절반 회전
        }
    }

    private static var count: Int { places.count }

    /// 사진은 seed 로 결정되는 외부 목 이미지다. **목 전용** — 실 API 가 붙으면 서버가 준 URL 을 쓴다.
    private static func images(src: Int, count: Int) -> [URL] {
        (0..<count).compactMap { URL(string: "https://picsum.photos/seed/gguk-\(src)-\($0)/800/600") }
    }

    private static let categories: [PinCategory] = [
        .popularAmongFriends, .manyStories, .savedByMany, .worthVisiting,
        .popularAmongFriends, .savedByMany, .manyStories, .worthVisiting,
        .popularAmongFriends, .savedByMany,
    ]

    /// 저장자 풀. `MockRoomRepository` 의 방 멤버(user-0001~0004)와 같은 사람들이라
    /// 방 멤버 목록과 카드의 아바타가 어긋나지 않는다.
    private static let members: [MemberProfile] = [
        MemberProfile(id: MemberID("user-0001"), nickname: "나", avatarColor: .red),
        MemberProfile(id: MemberID("user-0002"), nickname: "지훈", avatarColor: .redOrange),
        MemberProfile(id: MemberID("user-0003"), nickname: "서연", avatarColor: .orange),
        MemberProfile(id: MemberID("user-0004"), nickname: "민준", avatarColor: .green),
    ]

    /// 좌표는 **서로 다른 실제 값**이라야 지도 마커가 겹치지 않고 거리순 정렬도 눈으로 검증된다.
    /// `sourceURL` 이 nil 인 항목을 섞어 둔 건 "출처 없는 핀" 경로도 화면에서 밟아보기 위해서다.
    private static let places: [PlaceSeed] = [
        PlaceSeed("레이어스튜디오 10", "서울 성동구 상원4길 10", 37.5443, 127.0557, "카페", 3, 7, "https://www.instagram.com/p/mock-layer10/"),
        PlaceSeed("카페 온더플랜", "서울 마포구 연남로1길 39", 37.5620, 126.9250, "카페", 2, 0, "https://www.instagram.com/p/mock-ontheplan/"),
        PlaceSeed("을지다락", "서울 중구 을지로3가 301-19", 37.5662, 126.9917, "음식점", 1, 12, nil),
        PlaceSeed("성수연방", "서울 성동구 연무장5가길 7", 37.5417, 127.0561, "전시회", 3, 4, "https://www.instagram.com/p/mock-seongsu/"),
        PlaceSeed("피크닉 성수", "서울 성동구 서울숲2길 17-2", 37.5462, 127.0433, "카페", 2, 1, "https://www.instagram.com/p/mock-picnic/"),
        PlaceSeed("도어투성수", "서울 성동구 성수이로 113", 37.5427, 127.0602, "음식점", 1, 9, nil),
        PlaceSeed("라운드어바웃", "서울 마포구 양화로 162", 37.5546, 126.9226, "카페", 3, 2, "https://www.instagram.com/p/mock-roundabout/"),
        PlaceSeed("아보카도빌", "서울 용산구 회나무로13가길 53", 37.5385, 126.9928, "음식점", 2, 5, "https://www.instagram.com/p/mock-avocado/"),
        PlaceSeed("클럽 에스프레소", "서울 종로구 율곡로 83", 37.5776, 126.9838, "카페", 1, 0, nil),
        PlaceSeed("무드등 서울", "서울 강남구 선릉로157길 5", 37.5254, 127.0400, "전시회", 2, 3, "https://www.instagram.com/p/mock-moodeung/"),
    ]

    private struct PlaceSeed {
        let name: String
        let address: String
        let latitude: Double
        let longitude: Double
        let category: String
        let photoCount: Int
        let commentCount: Int
        let sourceURL: String?

        init(
            _ name: String, _ address: String, _ latitude: Double, _ longitude: Double,
            _ category: String, _ photoCount: Int, _ commentCount: Int, _ sourceURL: String?
        ) {
            self.name = name
            self.address = address
            self.latitude = latitude
            self.longitude = longitude
            self.category = category
            self.photoCount = photoCount
            self.commentCount = commentCount
            self.sourceURL = sourceURL
        }
    }
}

/// 목이 건네준 핀을 id 로 되찾기 위한 보관소.
///
/// 실 서버라면 단독 조회가 언제든 가능하지만, 목은 합성한 값을 기억해 둬야
/// 목록에서 본 것과 상세에서 보는 것이 같다. 합성을 두 번 하면 `createdAt` 이 어긋난다.
private actor MockPinStore {
    struct Entry {
        let pin: Pin
        let sourceURL: URL?
    }

    private var entries: [String: Entry] = [:]
    private var deleted: Set<String> = []

    func register(_ pin: Pin, sourceURL: URL?) {
        entries[pin.id.value] = Entry(pin: pin, sourceURL: sourceURL)
    }

    func entry(id: PinID) -> Entry? { entries[id.value] }

    func markDeleted(id: PinID) {
        deleted.insert(id.value)
    }

    /// 합성 직후의 핀 목록에서 지워진 것을 뺀다. 합성 자체를 건너뛰지 않는 건, 지운 뒤에도
    /// 상세 조회(`entry`)로는 닿을 수 있어야 이미 열려 있던 화면이 갑자기 오류로 바뀌지 않기 때문이다.
    func removingDeleted(_ pins: [Pin]) -> [Pin] {
        guard !deleted.isEmpty else { return pins }
        return pins.filter { !deleted.contains($0.id.value) }
    }
}
