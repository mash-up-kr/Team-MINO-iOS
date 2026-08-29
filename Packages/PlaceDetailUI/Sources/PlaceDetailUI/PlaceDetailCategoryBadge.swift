import Domain
import SwiftUI

/// ③ 장소분류 뱃지 — 스펙의 "홈의 장소분류 '카드정렬 값'을 따라간다" 를 그대로 옮긴 표다.
///
/// 홈 카드가 다는 큐레이션 라벨(``PinCategory``)과 **문구·색이 같아야** 같은 장소가 홈과 상세에서
/// 다르게 읽히지 않는다. 지금은 `FeatureHome` 의 카드 뱃지가 같은 표를 자기 안에 들고 있어 둘로
/// 나뉘어 있다 — 세 번째 화면이 같은 라벨을 요구하면 공용 자리로 내린다.
///
/// > `Place.category`(카페·음식점 같은 업종)와 다른 개념이다. 시안 005 네 화면이 모두 이 자리에
/// > 큐레이션 라벨을 두고 있다.
enum PlaceDetailCategoryBadge {
    static func of(_ category: PinCategory) -> (text: String, color: Color) {
        switch category {
        case .worthVisiting:        return ("가볼 만한 곳", .mhAccentForegroundLime)
        case .popularAmongFriends:  return ("친구들이 많이 본 곳", .mhAccentForegroundLightBlue)
        case .savedByMany:          return ("여럿이 저장한 곳", .mhAccentForegroundRedOrange)
        case .manyStories:          return ("이야기 많은 곳", .mhAccentForegroundPink)
        }
    }
}
