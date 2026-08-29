import Domain
import Foundation

struct PlaceDetailPlace: Equatable {
    let name: String
    let address: String
    /// 출처 게시글의 사진. 없을 수 있다 — 그러면 캐러셀 자체를 그리지 않는다.
    let photos: [URL]
    /// 이 장소를 저장한 사람. 서버가 주지 않으면 nil 이라 익명 아바타로 그린다.
    let sharer: MemberProfile?
    /// 홈 카드가 달고 있던 큐레이션 라벨. **홈에서 들어왔을 때만** 값이 있다 (Figma 002-1-1 ①:
    /// "저장 탭·지도·알림 등 홈 카드 이외의 경로로 진입한 경우에는 라벨을 노출하지 않는다").
    /// nil 이면 헤더가 라벨 자리를 통째로 뺀다.
    let label: PinCategory?
}

extension PlaceDetailPlace {
    /// - Parameter label: 상단에 노출할 큐레이션 라벨. **홈 카드로 진입한 경우에만** 넘긴다 —
    ///   핀 자신은 항상 라벨을 들고 있으므로(`pin.category`) 여기서 자동으로 채우면 저장 탭에서도
    ///   라벨이 떠 002-1-1 ① 을 어긴다. 그래서 핀에서 꺼내지 않고 호출부가 정한다.
    init(from pin: Pin, label: PinCategory?) {
        self.init(
            name: pin.place.name,
            address: pin.place.address,
            photos: pin.images,
            sharer: pin.createdBy,
            label: label
        )
    }
}

// 코멘트는 화면 전용 모델을 두지 않고 ``Domain/PinComment`` 를 그대로 쓴다.
//
// 예전에는 `PlaceDetailComment`(id·author·body)가 있었는데, 그건 Domain 에 코멘트 계약이
// 아예 없던 시절의 임시 모델이었다. 지금은 엔티티의 진부분집합이라 두면 "코멘트" 정의가 둘이
// 되고 읽을 때마다 옮겨 담아야 한다 — 옮기다 빠뜨리는 것이 곧 버그다.
// 반면 ``PlaceDetailPlace`` 는 남는다. 그쪽은 핀을 **다시 빚는다**(중첩된 `Pin.place` 를
// 펴고 화면이 쓰는 것만 남긴다). 옮겨 담을 값이 있으면 화면 모델, 없으면 엔티티 그대로다.
// `savedRooms: [Room]` 이 같은 판단으로 이미 엔티티를 그대로 든다.

/// ⑭ 코멘트 삭제 확인 다이얼로그가 겨냥한 코멘트. nil 이면 다이얼로그가 닫혀 있다.
///
/// 열림 여부를 Bool 로 두지 않는다 — "열렸다" 와 "무엇을 지운다" 가 갈라지면 확인을 누른 순간
/// 엉뚱한 줄이 사라진다. 방 상세의 장소 삭제(``RoomDetailDeletion``)와 같은 모양이다.
struct PlaceDetailCommentDeletion: Equatable, Identifiable {
    let commentID: PinCommentID
    /// 확인을 누른 뒤 응답을 기다리는 중 — 두 버튼을 모두 잠가 연타로 두 번 지우는 걸 막는다.
    var isSubmitting = false

    var id: PinCommentID { commentID }
}

extension PlaceDetailPlace {
    static let sample = PlaceDetailPlace(
        name: "레이어스튜디오 10",
        address: "서울 성동구 상원4길 10",
        photos: [
            URL(string: "https://picsum.photos/seed/gguk-0-0/800/600")!,
            URL(string: "https://picsum.photos/seed/gguk-0-1/800/600")!,
        ],
        sharer: MemberProfile(id: MemberID("user-0003"), nickname: "서연", avatarColor: .orange),
        label: .popularAmongFriends
    )
}

extension PinComment {
    /// 프리뷰용 표본. `c2` 만 앱이 목업으로 물려 둔 현재 사용자(`user-0001`)라, 프리뷰에서
    /// 케밥이 그 한 줄에만 붙는다.
    static let placeDetailSamples: [PinComment] = [
        PinComment(
            id: PinCommentID("c1"),
            pinID: PinID("p1"),
            author: MemberProfile(id: MemberID("user-0003"), nickname: "서연", avatarColor: .orange),
            body: "친구가 남긴 코멘트입니다.",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        ),
        PinComment(
            id: PinCommentID("c2"),
            pinID: PinID("p1"),
            author: MemberProfile(id: MemberID("user-0001"), nickname: "나", avatarColor: .red),
            body: String(repeating: "친구가 남긴 코멘트입니다.", count: 6),
            createdAt: Date(timeIntervalSince1970: 1_700_003_600)
        ),
        PinComment(
            id: PinCommentID("c3"),
            pinID: PinID("p1"),
            author: MemberProfile(id: MemberID("user-0004"), nickname: "에린", avatarColor: .green),
            body: String(repeating: "친구가 남긴 코멘트입니다.", count: 12),
            createdAt: Date(timeIntervalSince1970: 1_700_007_200)
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
