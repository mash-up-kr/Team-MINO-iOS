# MVI + Coordinator + DI 아키텍처

화면 아키텍처는 세 축으로 구성된다: **Coordinator**(화면 전환) + **MVI**(화면 내 상태) + **DI**(의존성 주입). 셋은 `Store` 하나로 수렴한다.

---

## 1. 모듈 구조

```
App ──▶ Feature* ──▶ Domain ──▶ Core
   │       ├───────▶ FlowCoordination        (Coordinator 프로토콜·FlowFinish·flowRoot · SwiftUI)
   │       ├───────▶ MVI                  (Effect·Store + MVITestSupport · Observation)
   │       └───────▶ *UI                  (공통 화면 — RoomCreationUI·MapUI …)
   │                   └──▶ DesignSystem · MVI
   └──▶ Data ──▶ Domain
            └──▶ Networking ──▶ Core
```

| 패키지 | 역할 |
|--------|------|
| **FlowCoordination** | `Coordinator` 프로토콜, `FlowFinish`, `flowRoot` modifier (영구 인프라) |
| **MVI** | `Effect`, `Store` / `MVITestSupport`의 `TestStore` (영구 인프라) |
| **Feature\*** | flow 단위. Coordinator·Route·NavigationStack 을 소유하고 화면을 배치한다 |
| **\*UI** | 여러 Feature 가 함께 쓰는 UI 모듈. 화면(`RoomCreationUI`)과 플랫폼·SDK 브릿지(`MapUI`) 둘 다. flow 를 소유하지 않는다 |

- `Store`/`Effect`는 `Observation`만 의존(SwiftUI 비의존) → reduce 단위 테스트가 UI 비의존
- `FlowCoordination`과 `MVI`는 **서로를 모른다**. "Store 생성 + 구독"을 묶는 일은 `Store.init(_:reduce:handle:)`(§4 "Store factory + 구독")이 맡는데, 그건 `Store` 자신의 기능이라 Coordinator 를 필요로 하지 않는다 — 덕분에 Coordinator 가 없는 진입점(`ShareViewController`)도 같은 보장을 받는다

### 공통 UI 레이어(`*UI`)

여러 Feature 가 같은 UI 를 쓰게 되면(예: 공동방 생성 → 친구초대를 온보딩과 방리스트가 함께 진입) 그것을 `*UI` 패키지로 내린다. **Feature 끼리 직접 의존하지 않기 위한 자리**다.

담기는 것은 두 종류다. 둘 다 아래 규칙을 똑같이 지킨다.

| | 예 | 성격 |
|---|---|---|
| 화면 | `RoomCreationUI` | State/Action/Nav·reducer·View. 상태를 든다 |
| 플랫폼·SDK 브릿지 | `MapUI` | `UIViewRepresentable` 래퍼와 순수 value type. 상태를 들지 않는다 |

- **`*UI` 는 Coordinator·Route·NavigationStack·FlowFinish 를 갖지 않는다.** 스택 소유는 소비하는 Feature 몫 — 그래야 같은 화면을 한쪽은 push 로, 다른 쪽은 cover 안 스택으로 띄울 수 있다.
- 그래서 `*UI` 의 View 는 Coordinator 대신 **`makeStore` 클로저**를 받는다. 특정 Coordinator 타입을 알면 다른 진입점에서 쓸 수 없기 때문(`RoomCreationUI.RoomFormView` 참조).

#### 허용 의존

| 의존 | | 이유 |
|---|---|---|
| `DesignSystem` | ⭕ | 화면을 그리는 부품 |
| `MVI` | ⭕ | `Store`·`Effect` |
| `Domain` | ⭕ | reduce 가 UseCase 를 받는다 (5절 체크리스트와 동일) |
| `Core` | ⭕ | 공용 유틸이 필요해지면 그때 선언한다 |
| 다른 `*UI` | ⭕ | 단방향이면 허용 — 화면이 브릿지를 쓰는 경우(방생성 카드의 지도 썸네일). **순환 금지** |
| `FlowCoordination` | ❌ | flow 를 소유하지 않으므로 Coordinator·FlowFinish 가 필요 없다 |
| `Feature*` | ❌ | 역방향. 여러 Feature 가 함께 쓰는 자리라 특정 Feature 를 알면 그 순간 못 쓴다 |
| `Data`·`Networking` | ❌ | Feature 도 모르는 레이어다. 화면이 Repository·API 를 직접 부르는 경로를 막는다 |

선언된 역방향 의존은 빌드가 잡지 못하므로(선언만 하면 컴파일된다) `Package.swift` 의 `dependencies` 대조가 유일한 게이트다. **지금은 기계 검사가 없어 리뷰에서 확인한다** — `layer-guard` 에 `Packages/*UI/Package.swift` 검사를 추가하는 건 후속 작업이다.

#### `DesignSystem` 과의 구분

기준은 **DesignSystem 에 넣을 수 있는가**다. 디자인 토큰만으로 그려지는 순수 부품(버튼·칩·그리드)은 `DesignSystem` 에 둔다. 다음 중 하나라도 해당하면 DS 에 넣을 수 없어 `*UI` 로 간다.

- **상태를 든다** — Store 를 가지면 `MVI` 의존이 생긴다 (`RoomCreationUI`)
- **외부 SDK·시스템 프레임워크에 의존한다** — DS 를 쓰는 모든 패키지가 그 의존을 상속받는다 (`MapUI` 의 GoogleMaps)

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
                catch is CancellationError { return }   // 취소는 결과가 없는 것이지 실패가 아니다
                catch { send(.loadFailed(error as? DomainError ?? .unknown)) }
            }
        case .loaded(let member): state.member = member; state.isLoading = false; return .none
        case .loadFailed(let error): state.error = error; state.isLoading = false; return .none   // 실패도 Response Action 으로 받아 state 갱신
        case .tapDetail: return .navigate(.goToDetail(id))    // 화면 전환도 Effect 로 (reduce 순수 유지)
        }
    }
}
```
- State는 단일 `Equatable` struct
- 비동기는 `.run`이 결과를 **Response Action**(`loaded`/`loadFailed`)으로 되돌려 state 갱신 — 성공·실패 **양쪽 다 case 로 받아** 처리한다(실패를 흘리지 않음)
- **취소는 `catch` 하기 전에 걸러낸다.** `catch` 하나로 다 받으면 화면 이탈·검색어 재입력으로 생긴 취소가 `.unknown` 오류가 되어 **정상 조작에 오류 UI가 뜬다**. 취소는 "결과를 못 얻은 것"이 아니라 "결과가 필요 없어진 것"이라 state 를 갱신하지 않고 빠져나간다
  - Repository 가 취소를 `CancellationError` 로 번역하는 규약은 `Packages/Networking/Docs/AddingAPI.md` 참조
  - 이때 `isLoading` 은 true 로 남는다. 취소는 화면을 떠났거나(state 폐기) 새 요청이 곧 다시 true 로 만드는 상황이라 대개 문제가 없다 — "취소하고 화면에 머무는" 흐름이 있으면 그 화면이 명시적으로 내려야 한다
- **에러를 State에 담는 모양**(평탄 `error: DomainError?` vs `enum LoadState`)은 화면마다 결정 — 위 `error` 필드는 예시일 뿐 강제 규칙 아님
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
- 종료되지 않는 Coordinator(루트/탭)는 `Output = Never`(`FlowFinish<Never>`)로 선언 → `callAsFunction(Never)`도 `finish()`(Void 오버로드)도 사라져 **발사가 컴파일 단계에서 불가능**. "죽은 finish"를 런타임 무시가 아니라 타입으로 차단한다. (자식에게 결과를 보고하는 flow는 `Output`을 결과 타입(enum)으로 둔다)

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

Coordinator의 `make<화면>Store`가 **DI 이음매**다: 주입받은 `deps.fetchXxx`(UseCase)를 reducer에 묶어 Store를 만든다. 이때 **`handle:` 을 받는 init 을 쓴다** — 구독이 생성에 묶여 있어 누락이 불가능하다(맨손 `init(_:reduce:)` + `observeNavigation` 은 누락 시 navigation 이 크래시·로그 없이 안 된다). 전체 형태는 5절 작성법 4)의 `makeHomeStore` 참조.

---

## 5. 새 Coordinator / 화면 작성법

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
    let finish = FlowFinish<Never>()   // 종료 없는 flow → Never 로 발사를 컴파일 차단. 자식에 결과 보고 시 FlowFinish<XxxResult> 처럼 결과 타입(enum)으로
    init(deps: XxxDeps) { ... }   // 화면 식별자 등 추가 입력이 있으면 init(deps:, xxxID:) 처럼 함께 받는다
    func makeHomeStore() -> XxxStore {                                // make<화면>Store — 화면(Store)마다 하나
        XxxStore(                                                     // handle: 이 구독까지 한다
            XxxState(),
            reduce: xxxReducer(useCase: deps.fetchXxx),
            handle: { [weak self] in self?.handle($0) }
        )
    }
    func handle(_ nav: XxxNav) { switch nav { ... } }   // 라우팅(테스트가 직접 호출)
}

// 5) View (생성자 주입) — 진입 화면. 파일명·폴더명은 화면 성격으로(예: Home/MemberHomeView)
struct XxxHomeView: View {
    let coordinator: XxxCoordinator           // 생성자 주입
    @State private var store: XxxStore?        // .task 에서 1회 lazy 생성

    var body: some View {
        @Bindable var coordinator = coordinator
        NavigationStack(path: $coordinator.path) { content }   // + 라우트 생기면 .navigationDestination, 시트는 .sheet(item:) 부착
    }

    @ViewBuilder private var content: some View {
        if let store {
            XxxHomeContentView(store: store)                   // store.state 를 읽어 그림. 진입 로드가 필요하면 이 뷰의 .task 에서 store.send(.load) (store 생성과 분리)
        } else {
            ProgressView()
                .task { store = coordinator.makeHomeStore() }  // store 없을 때만 실행 → 1회 생성 보장
        }
    }
    // .task 로 미루는 이유: makeHomeStore 가 @MainActor 라 non-isolated View.init 에서 직접 호출 불가
    //   + State(initialValue:)는 body 재평가마다 store 를 재생성·폐기해 @Observable 1회 생성 이점을 잃음
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

- [ ] `make<화면>Store` 는 **`Store(_:reduce:handle:)`** 로 만든다 — 구독이 생성에 묶여 누락이 불가능하다(맨손 `init(_:reduce:)` 는 `observeNavigation` 을 빠뜨리면 navigation 이 조용히 안 됨)
- [ ] reduce는 Repository가 아니라 **UseCase**를 받는다 (Repository 직접 주입하면 비즈니스 로직이 Feature로 샘)
- [ ] deps 프로토콜은 **자기 의존만** (번들 통째 주입은 `Feature→App` 역의존을 만들고, 다른 피쳐 UseCase까지 보임)
- [ ] View는 **생성자 주입**(@Environment·전역 컨테이너 금지 — 주입 누락을 런타임 크래시가 아니라 컴파일 에러로 차단)
- [ ] 자식 flow는 `finish`로 결과 보고, 부모는 `flowRoot`에서 **한 줄 위임**(`[weak]` 캡처)
- [ ] sheet/cover 자식 Coordinator는 부모가 strong 보유하고, **`onDismiss`로 정리**(스와이프 dismiss 포함)
- [ ] State/Action/Nav는 `Equatable`, Nav는 `Sendable`
- [ ] 로직 변경에는 같은 PR에 reduce 테스트(L1~L3)
- [ ] reduce 테스트(exhaustive)는 끝에 **`store.finish()` 호출** — 미처리 effect/nav가 검증 없이 통과하는 걸 막음 (deinit 자동화는 MainActor 격리·호출 타이밍 보장이 약해 미적용)

---

## 6. 확장성 — 방향은 확정, 구현은 트리거 때

아직 사례가 없어 미리 만들지 않지만(YAGNI), **생길 때 따를 방향은 정해져 있다.** 트리거별 적용 절차는 별도 문서로 분리했다 — **해당 트리거가 실제로 생기는 PR에서만** 펼쳐 본다(평소 자동 로드 비용 절감).

→ `.claude/docs/mvi-coordinator-di-extensions.md`

| 트리거 | 방향 |
|---|---|
| ~~두 번째 Coordinator~~ | ~~`makeStore` 공통화~~ → **완료**: `Store.init(_:reduce:handle:)` 로 해결 |
| 자식이 자기 UseCase를 가짐 | deps/factory 프로토콜 분리 + 4단계 전환 절차 |
| 두 번째 sheet 종류 | sheet enum 연관값에 자식 Coordinator 직접 담기 |
| 2단 중첩(자식의 자식 flow) | 재귀 패턴(자체 NavigationStack + 손자에 flowRoot) |

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
