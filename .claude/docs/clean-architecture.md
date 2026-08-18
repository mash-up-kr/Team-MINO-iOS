# Clean Architecture + DDD

## 의존성 규칙 (Dependency Rule)
- 의존성은 **반드시 바깥에서 안쪽으로만** 향한다: `Feature → Domain ← Data`
- **Domain은 어떤 외부 레이어도 알지 못한다** (Data, Feature, UIKit, SwiftUI 등 import 금지)
- Data와 Feature는 Domain에 의존하지만, 서로를 알지 못한다
- 구체 타입이 아닌 **추상(Protocol)에 의존**한다 (DIP)

## 레이어별 책임

| 레이어 | 책임 | 금지 사항 |
|--------|------|-----------|
| **Domain** | 비즈니스 로직, Entity, UseCase, Repository protocol | 프레임워크 의존 금지 (UIKit, Alamofire 등). **의존 패키지 0** — Core도 보지 않는다 |
| **Data** | Repository 구현, API 호출, DTO 변환, 로컬 저장소 | Domain Entity를 직접 수정 금지. DTO로 변환하여 전달 |
| **Feature** | UI, 사용자 입력 처리, 화면 상태 관리 | 비즈니스 로직 직접 구현 금지. UseCase를 통해서만 접근 |

## 경계 넘기 규칙
- Data → Domain 경계: `toDomain()` 매핑 메서드로 DTO를 Entity로 변환
- Domain → Data 경계: Repository Protocol (Domain에서 정의, Data에서 구현)
- Feature → Domain 경계: UseCase Protocol을 통해서만 접근
- **DTO가 Domain 레이어에 노출되면 안 된다**
- **Entity가 Codable/Decodable을 직접 준수하면 안 된다** (API 스키마와 결합 방지)

## DDD 원칙

### Entity
- 고유 식별자(id/key)로 구분되는 도메인 객체
- 순수 value type (struct), 프레임워크 비의존
- 비즈니스 의미를 담는 이름 사용 (DB 컬럼명이나 API 필드명 금지)

### Value Object
- 식별자 없이 값 자체로 동등성 비교 (`Equatable`)
- 불변 (let 프로퍼티)

### Repository
- 도메인 관점에서 컬렉션처럼 Entity에 접근하는 인터페이스
- Domain에 Protocol, Data에 구현체
- 내부적으로 API/DB/Cache를 어떻게 사용하는지는 Domain이 모름

### UseCase
- 하나의 비즈니스 유스케이스 = 하나의 UseCase 클래스
- 여러 Repository를 조합하여 비즈니스 흐름 구현
- UI 관심사(화면 상태, 네비게이션)를 포함하면 안 됨

## DDD 전술 패턴 — 이 저장소의 교본 규칙

아래 규칙은 실제 코드가 예시다. 새 도메인 개념을 만들 때 같은 모양을 따른다.

### 규칙은 Domain 에 산다 (anemic model 금지)

검증·계산·정책이 Feature/UI 에 있으면 안티패턴이다 — Fowler 가 말한 anemic domain model 은 객체에 "hardly any behavior on these objects" 인 상태로, 도메인 모델의 비용은 다 치르면서 이점은 얻지 못한다. Evans 의 Application layer 는 "This layer is kept thin" 이어야 한다.

| 규칙 종류 | 놓는 곳 | 예 |
|---|---|---|
| 입력 검증·정규화 | Value Object | `Nickname`·`RoomName`·`RoomMemo`·`CommentBody` |
| 한 Entity 의 자연스러운 계산 | Entity 메서드 | `Pin.savedDays(asOf:calendar:)` |
| 컬렉션 위에서 성립하는 정책 | 도메인 서비스 (`Services/`) | `PinCuration`(꾹 Pick·최신순) · `RoomOrdering`(개인방 우선) |

### 입력 VO — 코드에 실재하는 규칙만 담는다 (어포던스 발명 금지)

- 규칙이 화면마다 다르므로 어포던스도 차등이다: 라이브 클램프가 실재하면 `clampedDraft`, 거부 규칙이 실재하면 `init?`, 거부 규칙이 없으면 **비실패 `init`**(`RoomMemo`). 미구현 규칙("한글·영문만")은 VO 에 넣지 않고 주석으로 남긴다.
- 실패는 `init?` 로 표현한다 — 현 UI 가 실패 사유를 표시하지 않고 버튼 비활성만 하므로, 에러 enum 은 화면이 사유를 구분해야 할 때 추가한다(`DomainError` 와 같은 원칙).
- 상수(`minLength`/`maxLength`)는 VO 가 단일 출처다 — 화면 안내 문구·글자수 카운터가 같은 값을 읽는다.
- **화면의 입력 draft 는 String 으로 유지**한다(TextField 는 공백만·미달 길이 같은 중간 상태를 담아야 한다). VO 는 판정(`Nickname(name) != nil`)·정규화(`RoomName.clampedDraft`)·제출(`CommentBody(text)`) 시점에만 만든다.

### Aggregate 는 식별자로 참조한다

Vernon (IDDD): "Prefer references to external Aggregates only by their globally unique identity, not by holding a direct object reference." — `Pin.roomID: RoomID` 처럼 다른 aggregate 는 ID VO 로만 가리키고, Repository·UseCase 시그니처도 aggregate 통째가 아니라 식별자를 받는다(`PinRepository.pins(roomIDs:)`).

- 식별자는 원시 String 이 아니라 ID VO(`RoomID`·`PinID`·`MemberID`·`CommentID`)로 — 다른 리소스의 id 와 섞이는 실수를 타입이 막는다.
- ⚠️ ID VO 는 문자열 보간에서 `RoomID(value:"1")` 로 렌더된다 — 로그·accessibilityIdentifier 에는 반드시 `.value`. `CustomStringConvertible` 로 덮지 않는다(버그 은폐).
- Repository 는 aggregate root 단위로만 둔다 — Evans: "Provide repositories only for aggregate roots that actually need direct access."

### Domain 에 넣지 않는 것

- 표시 포맷 — "999+개" 캡, "N일째" 문구, `homeDisplayName`("…방"), 코멘트 작성자 "나", 뱃지 문구·색
- 플랫폼·외부 시스템 어댑터 — 애플지도 URL 조립(`PlaceDetailExternalMap`), Deeplink(Core)
- UI 선택 상태 — `RoomShareSelection` 같은 다중선택 모델
- 화면의 정렬 선택지 enum 과 dispatch — Domain 은 구현된 정책만 제공하고, 어떤 선택지를 노출할지는 Feature 가 정한다(`RoomDetailStore.applySort`)

### Swift 6 주의

- public struct 는 `Sendable` 이 자동으로 새어나가지 않는다 — 명시 선언
- VO·Entity 에 `Codable` 금지 유지, `Date()`·`Calendar.current` 는 주입으로(순수성·테스트 결정성)

## Core 배치 기준

- **Domain은 의존 패키지 0을 유지한다** (Core도 보지 않는다 — CI(layer-guard)가 검사). Domain에 필요한 순수 공용 타입은 Domain 안에 둔다.
- Core를 쓰고 싶은 패키지는 그때 자기 `Package.swift`에 의존을 추가한다. 쓰지 않는 의존을 미리 선언해 두지 않는다.
- Core에 프레임워크(UIKit·SwiftUI 등) 의존 유틸이 섞이면 Core를 의존하는 패키지가 그 의존을 상속받는다. 지금은 강제하지 않고, 필요해지면 Foundation-only 규칙과 `CorePlatform` 분리를 다시 검토한다.
