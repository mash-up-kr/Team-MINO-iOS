# Clean Architecture + DDD

## 의존성 규칙 (Dependency Rule)
- 의존성은 **반드시 바깥에서 안쪽으로만** 향한다: `Feature → Domain ← Data`
- **Domain은 어떤 외부 레이어도 알지 못한다** (Data, Feature, UIKit, SwiftUI 등 import 금지)
- Data와 Feature는 Domain에 의존하지만, 서로를 알지 못한다
- 구체 타입이 아닌 **추상(Protocol)에 의존**한다 (DIP)

## 레이어별 책임

| 레이어 | 책임 | 금지 사항 |
|--------|------|-----------|
| **Domain** | 비즈니스 로직, Entity, UseCase, Repository protocol | 프레임워크 의존 금지 (UIKit, Alamofire 등). Core만 허용 |
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
