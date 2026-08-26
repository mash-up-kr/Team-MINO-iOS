# 프로젝트 프로필 (project-profile)

> 마스터 스킬(ios-workflow 등)이 이 파일을 읽어 프로젝트에 적응한다. 슬롯 정의·채우는 법은 AI-Workflow 의 `deploy/templates/project-profile.template.md` 를 따른다.

## UI 프레임워크

- **프레임워크**: SwiftUI
- **레이아웃 방식**: SwiftUI 선언형

## 모듈 시스템

- **시스템**: 로컬 SPM 패키지
- **패키지 루트**: `Packages/`

## 빌드 오라클 명령

- **명령**: `xcodebuild build -project App/App.xcodeproj -scheme App -destination 'generic/platform=iOS Simulator'`
- App 스킴이 `ShareExtension` 타깃을 의존으로 물고 있어 익스텐션도 함께 빌드된다. 익스텐션만 따로 돌릴 때는 `-scheme ShareExtension`.

## 테스트 명령

각 `Package.swift` 의 `platforms` 선언이 러너를 가른다. macOS 를 선언한 패키지만 호스트에서 `swift test` 가 돈다.

| 대상 | 명령 |
|---|---|
| macOS 선언 패키지 (`MVI`·`FlowCoordination`·`Feature`·`Logging`·`Networking`) | `swift test --package-path Packages/<P>` |
| iOS 전용 패키지 (`Core`·`Domain`·`Data`·`DesignSystem`·`FeatureOnboarding`·`RoomCreationUI`·`ShareExtensionUI`) | `xcodebuild test -scheme <P> -destination 'platform=iOS Simulator,id=<UDID>'` |
| 앱 통합 | `xcodebuild test -project App/App.xcodeproj -scheme App -destination 'platform=iOS Simulator,id=<UDID>'` |

- **시뮬레이터 UDID 조회**: `xcrun simctl list devices available` — 이름 단독 지정은 동명 중복 위험이 있어 UDID 를 쓴다.
- `MapUI` 는 테스트 타깃이 없다.

## 동작 테스트 자동화

- **소환할 스킬**: `mino-qa`
- **입력 시나리오**: `/plan/pr{N}/consumable/user-test-cases.md`
- **판정 리포트 경로**: `/plan/pr{N}/consumable/qa-report.md`
- **미가용 시 동작**: 시뮬레이터 미부팅·`axe` 미설치면 전 항목을 사용자 수동 확인 대상으로 넘긴다. AXe 는 한글 입력을 못 하므로(US 키보드 한정) 한글 입력 흐름은 항상 수동으로 남긴다.

## 레이어 규칙 파일 (layer-rules.json)

- **경로**: (미정) — `layer-rules.json` 미도입
- **대조 메커니즘**: `.github/workflows/layer-guard.yml` 이 CI 에서 `Packages/Domain/Package.swift` 에 `.package(` 선언이 없는지 검사한다(Domain 의존 0). 그 외 레이어 방향은 `.claude/docs/clean-architecture.md` 가 1차 출처이며 기계 대조는 없다.

## 아키텍처 문서 경로 (architecture.md)

- **경로**: `.claude/docs/clean-architecture.md` (레이어·경계), `.claude/docs/mvi-coordinator-di.md` (화면 아키텍처)
- **아키텍처**: Clean Architecture + DDD / 화면은 MVI + Coordinator + 생성자 주입 DI

## 네이밍 규약 요약

- **요약**: 화면 단위 네이밍(`Xxx{Home,Detail,Form}{Store,View}`)·flow 폴더 배치·UseCase/Repository 접미사는 `.claude/docs/mvi-coordinator-di.md` 5절이 정의한다.
- **강제 메커니즘**: 프롬프트 규칙 (SwiftLint 커스텀 룰 미도입)

## 추가 판단 기준 스킬

- **스킬**: `swiftui-expert`, `swift-concurrency`, `swift-testing-expert`
- **적용 지점**: 구현·리뷰 양쪽

## 미채택·예외

- **SwiftLint 미도입** — `.swiftlint.yml` 없음, CLI 미설치. 축 B(코딩 스탠다드)의 기계 판정 다리가 없으므로 리뷰어의 컨벤션 대조로만 검사한다.
- **스냅샷 테스트 미채택** — 마크업 검증의 보조 오라클 없음.
