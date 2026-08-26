# MVI + Coordinator + DI — 확장성 (트리거별 적용)

본 아키텍처(→ `mvi-coordinator-di.md`)의 **아직 사례가 없어 미리 만들지 않은(YAGNI)** 확장 방향 모음.
**생길 때 따를 방향은 정해져 있다.** 해당 트리거가 실제로 생기는 PR에서만 이 문서를 펼쳐 적용한다(평소 자동 로드 대상 아님).

---

## ~~makeStore 공통화~~ — **완료(트리거 소진)**
"Store 생성 + observeNavigation 구독" 반복은 `Store.init(_:reduce:handle:)`(MVI) 로 묶어 해결했다.

한 번 `Coordinator.makeStore` 확장으로 넣었다가 `Store` 로 옮겼다. 헬퍼가 수신자(`Coordinator`)를 전혀 쓰지 않아 `FlowCoordination → MVI` 의존만 늘렸고, 정작 Coordinator 가 없는 진입점(`ShareViewController`)은 같은 두 줄을 손으로 다시 써야 했기 때문이다. 이 문서가 애초에 선호한 "구독을 store 생성에 묶는다"를 모듈 의존 없이 얻은 형태다.

**교훈**: 수신자를 안 쓰는 확장은 그 타입에 있을 이유가 없다 — 그 자리에 두면 의존만 늘고 적용 범위는 좁아진다.

## deps factory — 자식이 자기 UseCase를 가질 때
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

**전환 절차** — 지금은 자식(예: `MemberEditCoordinator`) 의존이 0개라 factory가 빈 껍데기가 되므로 미적용. **자식이 첫 UseCase를 갖는 PR에서** 아래를 함께 한다(부모 레이어가 자식 의존을 모르게 차단):
1. 자식에 좁은 deps 프로토콜 정의(예: `MemberEditDeps`) → 자식이 `init(deps:)`로 받게
2. 부모 `handle`의 직접 `new` 줄 교체: `editChild = MemberEditCoordinator()` → `editChild = factory.makeEditCoordinator()`
3. 부모 init 확장: `init(deps:, memberID:)` → `init(deps:, factory:, memberID:)`
4. 조립부: `AppDependencies`가 `MemberChildFactory` 채택(자식 deps를 알고 생성) + `AppCoordinator`가 부모 생성 시 `factory: deps` 전달

## 다중 sheet — 두 번째 sheet 종류가 생길 때
sheet enum의 **연관값에 자식 Coordinator를 직접 담아** "sheet 종류 ↔ child" 수동 동기화를 없앤다.
```swift
enum MemberSheet: Identifiable {
    case edit(MemberEditCoordinator)
    case share(ShareCoordinator)
    var id: String { switch self { case .edit: "edit"; case .share: "share" } }
}
```

## 2단 중첩 (자식의 자식 flow) — 2단이 생길 때
**재귀 패턴**: 자식 flow도 부모와 똑같이 자체 `NavigationStack(path: $coordinator.path)` + 손자에 다시 `flowRoot`. 트리 어느 깊이든 동일 패턴이 반복된다.
