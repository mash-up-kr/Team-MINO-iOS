import Foundation

/// 지도 위 카테고리 필터 칩. **`전체`/`카페`/`음식점` 3종 고정**이며 기본값은 `all` 이다.
///
/// PRD 「카테고리 필터」가 3종 고정으로 못박고 §2 비목표에도 *"저장 값 기반 동적 카테고리 생성:
/// 카테고리 필터는 `전체`/`카페`/`음식점` 3종 고정으로 한정한다"* 를 적었다. 시안 004-1 주석 ⑨ 의
/// "저장 값에서 추가되는 형식" 은 확정 이전의 동적 생성안이다. 서버 `category` 파라미터도 같은
/// 3종 enum 을 받아 값 집합이 양쪽에서 고정된다.
///
/// 이름을 `PinCategory`(핀에 붙는 「장소분류 라벨」 — 다른 개념이다)와 겹치지 않게 둔다.
/// 화면 표기(한글)와 서버 `category` 값은 각각 Feature·Data 가 붙인다 — Domain 은 개념만 든다.
public enum PlaceCategoryFilter: CaseIterable, Equatable, Hashable, Sendable {
    /// 전체 — 거르지 않는다. **기본값이다.**
    case all
    /// 카페
    case cafe
    /// 음식점
    case restaurant
}
