import Foundation
import Domain

/// 백엔드 미연결 단계용 `PinRepository` 구현. 네트워크 대신 하드코딩 장소 풀로 핀을 합성한다.
/// 추후 네트워크 `PinRepositoryImpl`(DTO → `toDomain()` 매핑) 로 교체하면 이 파일만 지운다.
///
/// 리듀서가 목 데이터를 직접 만들지 않도록(순수성·아키텍처 경계) 여기로 옮겨온 것 —
/// `page` 로 고정 풀을 회전시켜 "더 보기"마다 다른 카드처럼 보이게 한다.
public final class MockPinRepository: PinRepository {
    public init() {}

    public func pins(rooms: [Room]) async throws -> [Pin] {
        rooms.flatMap { Self.makePins(for: $0, page: 0) }
    }

    public func pins(room: Room, page: Int) async throws -> [Pin] {
        Self.makePins(for: room, page: page)
    }

    // MARK: - Mock 합성

    private static let categories: [PinCategory] = [
        .popularAmongFriends, .manyStories, .savedByMany, .worthVisiting,
        .popularAmongFriends, .savedByMany, .manyStories, .worthVisiting,
        .popularAmongFriends, .savedByMany,
    ]

    private static let places: [(title: String, address: String)] = [
        ("레이어스튜디오 10", "서울 성동구 상원4길 10"),
        ("카페 온더플랜", "서울 마포구 연남로1길 39"),
        ("을지다락", "서울 중구 을지로3가 301-19"),
        ("성수연방", "서울 성동구 연무장5가길 7"),
        ("피크닉 성수", "서울 성동구 서울숲2길 17-2"),
        ("도어투성수", "서울 성동구 성수이로 113"),
        ("라운드어바웃", "서울 마포구 양화로 162"),
        ("아보카도빌", "서울 용산구 회나무로13가길 53"),
        ("클럽 에스프레소", "서울 종로구 율곡로 83"),
        ("무드등 서울", "서울 강남구 선릉로 157길 5"),
    ]

    private static func makePins(for room: Room, page: Int) -> [Pin] {
        let now = Date.now
        let count = places.count
        // page 마다 풀을 회전시켜 다른 카드처럼 보이게 하고, id 에 page 를 넣어 이전 페이지와 겹치지 않게 한다.
        return (0..<count).map { i in
            let src = (i + page) % count
            return Pin(
                id: PinID("pin-\(room.id.value)-\(page)-\(i)"),
                roomID: room.id,
                category: categories[src],
                title: places[src].title,
                address: places[src].address,
                createdAt: now.addingTimeInterval(Double(-i) * 86400)
            )
        }
    }
}
