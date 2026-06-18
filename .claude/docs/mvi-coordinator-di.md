# MVI + Coordinator + DI 아키텍처

화면 아키텍처는 세 축으로 구성된다: **Coordinator**(화면 전환) + **MVI**(화면 내 상태) + **DI**(의존성 주입). 셋은 `Store` 하나로 수렴한다.

---

## 1. 모듈 구조

```
App ──▶ Feature ──▶ Domain ──▶ Core
   │       ├──────▶ FlowCoordination     (Coordinator 프로토콜·FlowFinish·flowRoot · SwiftUI)
   │       └──────▶ MVI                  (Effect·Store + MVITestSupport · Observation)
   └──▶ Data ──▶ Domain
            └──▶ Networking ──▶ Core
```

| 패키지 | 역할 |
|--------|------|
| **FlowCoordination** | `Coordinator` 프로토콜, `FlowFinish`, `flowRoot` modifier (영구 인프라) |
| **MVI** | `Effect`, `Store` / `MVITestSupport`의 `TestStore` (영구 인프라) |
| **Feature** | 화면별 State/Action/Nav·reducer·Coordinator·SwiftUI View |

- `Store`/`Effect`는 `Observation`만 의존(SwiftUI 비의존) → reduce 단위 테스트가 UI 비의존
- `FlowCoordination`과 `MVI`는 서로 모른다. 둘을 잇는 건 Feature의 Coordinator

---

## 2. MVI

순수 reduce + 최소 Effect/Store. 비동기 결과는 Response Action으로 복귀, 화면 전환은 NavigationEffect로 분리한다.

### Effect

```swift
public enum Effect<Action, Nav> {
    case none
    case run(@MainActor (_ send: @MainActor @escaping (Action) -> Void) async -> Void)
    case navigate(Nav)
}
```
reduce는 부수효과를 **직접 실행하지 않고 값으로 반환**한다. 실행은 `Store`가 맡는다.

### Store

```swift
@Observable @MainActor
public final class Store<State, Action, Nav: Sendable> {
    public private(set) var state: State
    public init(_ initial: State, reduce: @escaping (inout State, Action) -> Effect<Action, Nav>)
    public func send(_ action: Action)
    public func observeNavigation(_ handler: @escaping @MainActor (Nav) -> Void)  // 단일 소비자
}
```
- `send` → `reduce` → 반환된 `Effect`를 Store가 실행: `.run`은 Task로, `.navigate`는 navigation 채널로 yield
- **`observeNavigation`**: navigation 구독을 Store가 직접 관리(구독 Task를 자기 수명에 묶어 정리). Coordinator는 `effectTasks` 같은 보일러플레이트를 안 가진다. 단일 소비자(중복 호출은 디버그 assert)

### 순수 reduce + Response Action

```swift
func memberHomeReducer(useCase: FetchMemberUseCase, id: MemberID)
    -> (inout MemberHomeState, MemberHomeAction) -> Effect<MemberHomeAction, MemberHomeNav> {
    { state, action in
        switch action {
        case .load:
            state.isLoading = true
            return .run { send in
                do    { send(.loaded(try await useCase.execute(id: id))) }
                catch { send(.loadFailed(error as? DomainError ?? .unknown)) }
            }
        case .loaded(let member): state.member = member; state.isLoading = false; return .none
        case .tapDetail: return .navigate(.goToDetail(id))    // 화면 전환도 Effect 로 (reduce 순수 유지)
        }
    }
}
```
- State는 단일 `Equatable` struct
- 비동기는 `.run`이 결과를 **Response Action**(`loaded`/`loadFailed`)으로 되돌려 state 갱신
- 의존성은 `Effect.run` 안에서만 사용 — reduce 시그니처는 순수 유지

### TestStore (L1~L3, MVITestSupport)

```swift
await store.send(.load) { $0.isLoading = true }          // 동기 변화 단언
await store.receive(.loaded(member)) { $0.member = member; $0.isLoading = false }  // effect 결과
store.receiveNavigation(.goToDetail(id))                  // navigation 단언
store.finish()                                            // 미처리 effect/nav 잔여 검사
```
- **L1**(순수 reduce 전이) / **L2**(비동기 시나리오) / **L3**(exhaustive — 미단언 변화·미수신 effect 자동 실패)
- `exhaustive = false`: 중간 단언과 finish 잔여 검사를 끄고 최종만 `currentState`로 확인
- production `Store`의 실행 엔진은 `StoreTests`가 별도 검증(TestStore.drain과 Store.execute는 별개 구현)

### 절제 규칙 (경량 유지)

- 1 effect = 1 작업 = 1 결과 action. `merge`/`flatMap` 콤비네이터 금지. 병렬은 `async let`→1 action
- 취소는 `Task` 핸들로. `EffectID`/`.cancellable` 직접 구현 안 함
- 이 선을 넘는 복잡도(점진 렌더링, 정교한 취소 다수)가 생기면 TCA 재평가 트리거

---

## 3. Coordinator

### 단일 프로토콜

능력별로 쪼개지 않고 path/sheet/cover/finish를 한 프로토콜에 통합한다. 안 쓰는 능력은 `Never`/`Void` 기본값.

```swift
@MainActor
public protocol Coordinator: AnyObject {
    associatedtype Route: Hashable
    associatedtype Sheet: Identifiable = Never
    associatedtype Cover: Identifiable = Never
    associatedtype Output = Void
    var path: [Route] { get set }
    var sheet: Sheet? { get set }
    var cover: Cover? { get set }
    var finish: FlowFinish<Output> { get }
}
// extension: push/pop/popToRoot/present/dismiss 기본 구현
```
- `@Observable @MainActor final class`로 채택
- 루트/탭 Coordinator는 `finish`를 미사용(빈 `FlowFinish<Void>()` — 단일 프로토콜의 수용된 대가)

### FlowFinish — 자식→부모 1회성 결과 채널

```swift
@MainActor public final class FlowFinish<Output> {
    public func bind(_ action: @escaping (Output) -> Void)   // action 만 교체(didFire 안 건드림)
    public func callAsFunction(_ output: Output)             // 1회만 발사(이중 실행 방어)
    public func reset()                                      // 재발사가 필요할 때만 명시적으로
}
```
- 자식이 `finish(result)`로 결과를 1회 보고. 취소/완료는 `Output` 타입(enum)으로 표현
- **1회성 보장**: `bind`는 발사 상태를 리셋하지 않는다 → `flowRoot`의 `onAppear` 재호출로 중복 발사되지 않음

### flowRoot — 시트/커버 루트에 finish 연결

```swift
.flowRoot(child) { [weak parentCoordinator] result in
    parentCoordinator?.editDidFinish(result)   // 부모 메서드로 한 줄 위임 (retain cycle 방지: weak)
}
```

### 두 출력 채널

| 채널 | 방향 | 용도 |
|---|---|---|
| **NavigationEffect** (`Effect.navigate` → `observeNavigation`) | Store → Coordinator | 화면 내 push/present, 다수 |
| **FlowFinish** | 자식 Coordinator → 부모 | flow 종료(결과 보고), 1회 |

---

## 4. DI

### Coordinator별 좁은 deps 프로토콜

각 Coordinator는 **자기가 쓰는 의존만** 담은 좁은 프로토콜을 받는다. 사용처는 자기 것만 보고(캡슐화/ISP), Composition Root가 모든 프로토콜을 준수한다.

```swift
// Feature — 자기 의존만
public protocol MemberDeps {
    var fetchMember: FetchMemberUseCase { get }   // reduce 는 Repository 가 아니라 UseCase 를 받는다
}
final class MemberCoordinator {
    init(deps: MemberDeps, memberID: MemberID)
}

// App — Composition Root 가 모든 deps 프로토콜을 준수
struct AppDependencies: MemberDeps {
    let fetchMember: FetchMemberUseCase
}
```
- **사용처(Coordinator)는 좁은 창**만 본다 → 다른 피쳐 UseCase 안 보임
- **조립처(AppDependencies)는 전부 안다** → Composition Root의 정상 역할(피쳐별 extension으로 분리 가능)
- 보일러플레이트(프로토콜 정의)는 AI가 흡수 → "테스트/안전 우선" 가치를 택함

### View는 생성자 주입

```swift
public struct MemberHomeView: View {
    private let coordinator: MemberCoordinator
    public init(coordinator: MemberCoordinator) { self.coordinator = coordinator }
    public var body: some View {
        @Bindable var coordinator = coordinator        // navigation 바인딩
        NavigationStack(path: $coordinator.path) { ... }
    }
}
```
- `@Environment(Coordinator.self)` 대신 **생성자 주입** → 주입 누락이 런타임 크래시가 아니라 **컴파일 에러**로 차단, 의존 명시
- Coordinator는 flow 단위라 뷰 계층이 얕아 @Environment 자동 전파의 이점이 작다

### Store factory + 구독

```swift
func makeHomeStore() -> MemberHomeStore {
    let store = MemberHomeStore(MemberHomeState(), reduce: memberHomeReducer(useCase: deps.fetchMember, id: memberID))
    store.observeNavigation { [weak self] in self?.handle($0) }   // ← 반드시 호출 (누락 시 navigation 동작 안 함)
    return store
}
```

---

## 5. 새 Coordinator / 화면 작성법

새 피쳐를 추가할 때 따르는 절차와 체크리스트.

### 파일 배치

피쳐는 `Feature` 패키지 안에서 **flow 폴더 하나**로 묶는다(타입 종류별로 흩지 않는다). flow 폴더 안에서는 **화면마다 폴더**(`Store` + `View` 한 쌍)를 두고, flow 공통(Coordinator·Deps)은 루트에 둔다.

```
Packages/Feature/Sources/Feature/Member/    # 예: Member flow
  MemberCoordinator.swift          # flow Coordinator (Route/Sheet enum 포함)
  MemberDeps.swift                 # deps 프로토콜
  Home/                            # 진입 화면
    MemberHomeStore.swift            # State / Action / Nav / reducer (화면 단위)
    MemberHomeView.swift
  Detail/                          # 그 외 화면
    MemberDetailStore.swift
    MemberDetailView.swift
  Edit/                            # 자식 flow — 부모와 같은 재귀 패턴(미니 flow)
    MemberEditCoordinator.swift      # 자식 flow Coordinator (루트에)
    Form/                            # 자식 flow의 진입 화면
      MemberEditFormView.swift         # (자식 의존/Store 가 생기면 MemberEditDeps·MemberEditFormStore 추가)
```
- **화면 = Store 1개 = 폴더 1개**. 화면이 하나여도 폴더로 둔다 → 화면이 늘 때 새 폴더만 추가(additive), 기존 파일 이동 없음.
- 폴더명 = **화면 성격**(`Home`·`Detail`·`Form`…), 파일명도 폴더와 일치(`Home/MemberHomeView`). "어디가 진입 화면인지"는 Coordinator 코드로 드러난다(폴더명에 `Root` 같은 위치어를 쓰지 않는다).
- 자식 flow도 동일 규칙 — flow 폴더(`Edit/`)에 Coordinator를 루트에 두고, 그 안에서 화면마다 성격 폴더(`Form/`…).
- UseCase·Repository·Entity 등 **도메인 타입은 여기 두지 않는다** → 공유 `Domain` 패키지(타입별 폴더). Feature는 Domain까지만 import.
- (피쳐가 늘어 독립 빌드/경계 강제가 필요해지면 `FeatureXxx` 별도 패키지로 승격 — 트리거 시 결정)

```swift
// 0) 선행: 이 화면이 쓸 UseCase·Repository·Entity 를 공유 Domain(+ Data 구현)에 먼저 만든다.
//    reduce 는 UseCase 를 받으므로, FetchXxxUseCase 가 없으면 1) 부터 시작해도 막힌다.
//    레이어 규칙(Entity 의 Codable 금지, toDomain 매핑, Repository protocol 위치 등)은 → .claude/docs/clean-architecture.md

// 1) State / Action / Nav (모두 Equatable, Nav 는 Sendable)
struct XxxState: Equatable { ... }
enum XxxAction: Equatable { case load, loaded(...), tapYyy }
enum XxxNav: Equatable, Sendable { case goToYyy(...) }
typealias XxxStore = Store<XxxState, XxxAction, XxxNav>

// 2) 순수 reduce (의존은 UseCase, Effect.run 안에서만 사용)
func xxxReducer(useCase: FetchXxxUseCase) -> (inout XxxState, XxxAction) -> Effect<XxxAction, XxxNav> { ... }

// 3) deps 프로토콜 (자기 UseCase 만)
protocol XxxDeps { var fetchXxx: FetchXxxUseCase { get } }

// 4) Coordinator (@Observable @MainActor final class)
final class XxxCoordinator: Coordinator {
    var path: [XxxRoute] = []
    var sheet: Never? = nil
    var cover: Never? = nil
    let finish = FlowFinish<Void>()
    init(deps: XxxDeps) { ... }   // 화면 식별자 등 추가 입력이 있으면 init(deps:, xxxID:) 처럼 함께 받는다
    func makeStore() -> XxxStore {
        let store = XxxStore(XxxState(), reduce: xxxReducer(useCase: deps.fetchXxx))
        store.observeNavigation { [weak self] in self?.handle($0) }   // 필수
        return store
    }
    func handle(_ nav: XxxNav) { switch nav { ... } }   // 라우팅(테스트가 직접 호출)
}

// 5) View (생성자 주입) — 진입 화면. 파일명·폴더명은 화면 성격으로(예: Home/MemberHomeView)
struct XxxHomeView: View {
    let coordinator: XxxCoordinator
    @State private var store: XxxStore?
    // .task 에서 store 1회 생성
}
```

마지막으로 App(Composition Root)에 끼운다 — 화면을 다 만든 뒤 빠뜨리기 쉬운 단계다.

```swift
// 6-a) AppDependencies 가 XxxDeps 를 준수 (의존 1개면 프로퍼티 추가, 여러 피쳐면 extension 으로 분리 가능)
struct AppDependencies: MemberDeps, XxxDeps {
    let fetchMember: FetchMemberUseCase
    let fetchXxx: FetchXxxUseCase          // ← XxxDeps 요구 추가
    init() {
        self.fetchMember = ...
        self.fetchXxx = DefaultFetchXxxUseCase(repository: XxxRepositoryImpl(client: client))
    }
}

// 6-b) AppCoordinator 가 자식 Coordinator 를 strong 보유
@Observable @MainActor
final class AppCoordinator {
    let xxx: XxxCoordinator
    init(deps: AppDependencies) {
        self.xxx = XxxCoordinator(deps: deps)   // deps 는 AppDependencies 가 XxxDeps 로서 전달
    }
}

// 6-c) 앱 루트 View(또는 탭/디스패처)가 자식 flow 진입 View 를 연결
XxxHomeView(coordinator: appCoordinator.xxx)
```

### 체크리스트

- [ ] `makeStore` 안에서 **`store.observeNavigation { handle }` 호출** — 누락 시 navigation이 크래시·로그 없이 안 됨
- [ ] reduce는 Repository가 아니라 **UseCase**를 받는다 (Repository 직접 주입하면 비즈니스 로직이 Feature로 샘)
- [ ] deps 프로토콜은 **자기 의존만** (번들 통째 주입은 `Feature→App` 역의존을 만들고, 다른 피쳐 UseCase까지 보임)
- [ ] View는 **생성자 주입**(@Environment·전역 컨테이너 금지 — 주입 누락을 런타임 크래시가 아니라 컴파일 에러로 차단)
- [ ] 자식 flow는 `finish`로 결과 보고, 부모는 `flowRoot`에서 **한 줄 위임**(`[weak]` 캡처)
- [ ] sheet/cover 자식 Coordinator는 부모가 strong 보유하고, **`onDismiss`로 정리**(스와이프 dismiss 포함)
- [ ] State/Action/Nav는 `Equatable`, Nav는 `Sendable`
- [ ] 로직 변경에는 같은 PR에 reduce 테스트(L1~L3)

---

## 6. 확장성 — 방향은 확정, 구현은 트리거 때

아직 사례가 없어 미리 만들지 않지만(YAGNI), **생길 때 따를 방향은 정해져 있다.**

### makeStore 공통화 (P3 / framework 추출) — 두 번째 Coordinator 때
`makeStore`의 "Store 생성 + observeNavigation 구독" 패턴이 Coordinator마다 반복된다. 두 번째 Coordinator가 생기면 이 패턴을 인프라 헬퍼로 추출하거나, **문서 체크리스트(5절)로 누락을 방지**한다. (구독을 store 생성에 묶으면 누락이 구조적으로 불가능해지나, 모듈 의존을 엮어야 해 사례 2개를 보고 결정)

### deps factory — 자식이 자기 UseCase를 가질 때
자식 Coordinator가 부모와 **다른 의존**을 가지면, **데이터(deps)와 생성(factory)을 별도 프로토콜로 분리**한다.
```swift
protocol MemberDeps { var fetchMember: FetchMemberUseCase { get } }       // 데이터(순수)
protocol MemberChildFactory { func makeEditCoordinator() -> MemberEditCoordinator }  // 생성 책임
final class MemberCoordinator {
    init(deps: MemberDeps, factory: MemberChildFactory)   // 자식 늘어도 init 인자 2개 고정
}
extension AppDependencies: MemberChildFactory { func makeEditCoordinator() -> ... { .init(deps: self) } }
```
- 자식이 **없는** Coordinator는 `factory` 없이 `init(deps:)`만 (자식 유무가 시그니처에 드러남)

### 다중 sheet — 두 번째 sheet 종류가 생길 때
sheet enum의 **연관값에 자식 Coordinator를 직접 담아** "sheet 종류 ↔ child" 수동 동기화를 없앤다.
```swift
enum MemberSheet: Identifiable {
    case edit(MemberEditCoordinator)
    case share(ShareCoordinator)
    var id: String { switch self { case .edit: "edit"; case .share: "share" } }
}
```

### 2단 중첩 (자식의 자식 flow) — 2단이 생길 때
**재귀 패턴**: 자식 flow도 부모와 똑같이 자체 `NavigationStack(path: $coordinator.path)` + 손자에 다시 `flowRoot`. 트리 어느 깊이든 동일 패턴이 반복된다.

---

## 7. 테스트 전략

| 레벨 | 대상 | 도구 |
|---|---|---|
| 화면 로직(대부분) | reducer L1~L3 | `TestStore` (mock UseCase 직접 주입, DI 무관) |
| navigation 라우팅 | `Coordinator.handle` 직접 호출 | 결정적(구독과 분리) |
| Store 실행 엔진 | navigate yield / run effect 반영 | `StoreTests` (production Store 직접) |
| flow 종료 | `FlowFinish` 1회성·재bind·취소 | `FlowFinishTests` |

- 대부분의 로직은 **reducer 테스트**가 mock·대기 없이 결정적으로 검증한다(테스트 강력함 1순위)
- View 자체는 단위 테스트하지 않는다(생성자 주입이라 도입 시 mock 주입은 단순)
- 비동기 대기는 폴링 상한을 넉넉히 두거나(유한 종료) 콜백 기반으로 — 무한 hang 금지

### 실행 (검증 명령)

인프라·reducer 로직은 패키지 단위로 빠르게(호스트 빌드), 앱 통합은 시뮬레이터로 검증한다.

```bash
# 패키지 단위 (UI 비의존, 빠름)
swift test --package-path Packages/MVI               # Store 실행 엔진 + TestStore + reducer L1~L3
swift test --package-path Packages/FlowCoordination  # FlowFinish 1회성·재bind·취소
swift test --package-path Packages/Feature           # reducer 시나리오 + Coordinator.handle 라우팅

# 앱 통합 (전 레이어 빌드 + 테스트, 시뮬레이터)
xcodebuild -project App/App.xcodeproj -scheme App \
  -destination 'platform=iOS Simulator,name=iPhone 16' build test
```
- 로직만 바꿨으면 해당 패키지 `swift test` 로 충분(초 단위). 앱 진입/조립을 건드렸을 때만 `xcodebuild` 통합 실행
- 시뮬레이터 이름(`iPhone 16` 등)은 `xcrun simctl list devices` 로 설치된 것 확인 후 맞춘다
