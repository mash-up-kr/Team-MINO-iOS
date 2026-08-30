import Domain
import Foundation

/// 홈 사용 가이드가 가리키는 카드 덱의 **모형 데이터** (Figma 「홈 튜토리얼」 node 4334-216197).
///
/// 가이드가 떠 있는 동안 홈은 실제 덱 대신 이 5장을 그린다. 안내가 실제 데이터에 얹히면 화면이
/// 계정마다 달라지기 때문이다 — 장소가 0장이면 손 그래픽이 빈 상태 일러스트를 가리키게 되고,
/// 1~2장이면 시안의 겹친 스택이 안 나오며, 사진 유무·제목 길이에 따라 카드 모양도 매번 달라진다.
/// 안내는 "무엇이 저장돼 있는지"가 아니라 "이 화면을 어떻게 쓰는지"를 말하는 화면이라,
/// 가리킬 대상을 데이터가 아니라 시안이 정하게 둔다.
///
/// 카드 내용은 시안의 `home_card` 인스턴스를 그대로 옮긴 값이다(뱃지·제목·주소가 다섯 장 모두 같다).
/// 장 수(5)는 덱이 한 번에 겹쳐 보여 주는 수(``CardDeckLayout/visibleCount``)와 같아, 시안처럼
/// 스택이 가득 찬 모습이 된다.
enum HomeGuideMockDeck {

    /// 시안의 카드 다섯 장. 겹쳐 보이는 만큼만 만든다(더 만들어도 화면에 나오지 않는다).
    static let pins: [Pin] = (0..<CardDeckLayout.visibleCount).map(mockPin(index:))

    /// 방 뱃지 표기의 폴백. 방을 아직 못 읽었을 때만 쓴다 — 방이 있으면 진짜 방 이름을 그린다.
    /// 안내 문구가 "방 뱃지와 토끼를 클릭하면" 이라 뱃지 자체는 비워 둘 수 없고, 가입 직후 계정이
    /// 실제로 열게 되는 첫 방이 개인방("내 장소")이라 그 표기를 그대로 쓴다.
    static let roomBadgeTitle = "내 장소"

    /// 모형 카드 한 장. 사진은 넣지 않는다 — 시안의 사진은 디자인 시스템 `home_card` 의 기본 플레이스홀더
    /// (50% 로 깔린 클립아트)라 앱이 들고 있을 에셋이 아니고, 사진 없는 핀에 DS 가 그리는 빈 타일
    /// (`Background/Normal/Alternative` #F7F7F8)이 시안의 타일 색(#F4F4FE)과 사실상 같은 자리를 만든다.
    /// 그 위는 어차피 손 그래픽과 안내 문구가 덮는다.
    private static func mockPin(index: Int) -> Pin {
        Pin(
            id: PinID("home-guide-mock-\(index)"),
            roomID: "home-guide-mock",
            place: Place(
                id: PlaceID("home-guide-mock-place-\(index)"),
                name: "레이어스튜디오 10",
                address: "서울 성동구 상원4길 10",
                // 모형 카드는 좌표를 쓰지 않는다(지도를 열지 않고, 가이드 중엔 탭도 막힌다).
                coordinate: Coordinate(latitude: 0, longitude: 0)
            ),
            // 색을 고르지 않은 계정과 같은 아바타(소품 없는 검은 얼굴) — 시안의 카드 아바타가 그것이다.
            createdBy: MemberProfile(id: MemberID("home-guide-mock"), nickname: "꾹이", avatarColor: nil),
            category: .worthVisiting,   // 뱃지 "가볼 만한 곳"
            // 표시에 쓰이지 않는 값이라 고정한다 — 화면이 실행 시각에 따라 달라지지 않게.
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}
