# Team-MINO-iOS

Mash-Up MINO 팀의 iOS 앱입니다. SwiftUI 위에 **Clean Architecture** 구조로 만들고, 화면 아키텍처는 **MVI**를 씁니다. 모듈은 레이어 단위로 SPM 패키지를 나눠서 구성합니다. 외부 라이브러리 없이 애플 프레임워크만 쓰는 걸 기본 방향으로 합니다.

## 아키텍처 — 모듈 의존 레이어

의존성은 **바깥에서 안쪽으로만** 향합니다 (`Feature → Domain ← Data`). 가장 안쪽에 있는 Domain은 바깥을 모르고, Data가 거꾸로 Domain의 프로토콜에 의존합니다(의존성 역전). 아직 없는 조각(`CorePlatform`, 실 API 조립)은 NEW·점선으로 표시했고, 트리거가 오면 그때 만듭니다.

<div align="center">
  <img src="docs/images/target-architecture.svg" alt="모듈 의존 레이어" width="900" />
</div>

## 화면 아키텍처

### MVI — 단방향 데이터 흐름

상태는 순수 `reduce` 함수가 만들고, 부수효과는 `Effect` 값으로 반환해서 `Store`가 실행합니다. 비동기 결과는 Response Action(`loaded`/`loadFailed`)으로 다시 돌아오고, 화면 전환은 `.navigate`로 Coordinator에 넘깁니다. `Store`는 Observation만 쓰고, Combine 대신 async/await 기반 스트림으로 비동기를 처리합니다.

<div align="center">
  <img src="docs/images/mvi.svg" alt="MVI 단방향 데이터 흐름" width="900" />
</div>

### DI — 컴포지션 루트

전역 컨테이너 없이 생성자 주입만 씁니다. 각 Coordinator는 자기 의존만 담은 좁은 deps 프로토콜을 받고, `AppDependencies` 한 타입이 모든 deps 프로토콜을 준수합니다 — 주입을 빠뜨리면 런타임 크래시가 아니라 컴파일 에러로 바로 드러납니다.

<div align="center">
  <img src="docs/images/di.svg" alt="DI — 컴포지션 루트와 좁은 deps 프로토콜" width="900" />
</div>

## AI 활용

극한의 에이전틱 코딩을 위해 AI를 적극 활용합니다.

- **Figma → PR 워크플로우** — 피그마 URL 하나만 넣으면 화면 구현부터 테스트, QA까지 이어서 돌아가는 [Mino-harness](https://github.com/hooni0918/Mino-harness) 워크플로우를 씁니다. 사람이 하나씩 보는 대신, 피그마 원본과 다시 비교하고 빌드가 되는지 확인하는 식으로 자동 검증합니다.
- **팀 문서 · 공통 규칙** — [mino-Wiki](https://mino-qa.vercel.app/) 사이트에 RAG 챗봇이 있어서, 문서와 팀 공통 규칙을 바로 물어볼 수 있습니다.

### 첫 세팅 (팀원)

레포를 클론하고 Claude Code에서 프로젝트 폴더를 신뢰하면, `.claude/settings.json`이 워크플로우 플러그인 설치를 안내합니다. 수락하면 `/ios-workflow`·`/code-review` 같은 스킬이 `ai-workflow:` 접두사로 들어옵니다. 안내가 안 뜨면 직접 두 줄:

```
/plugin marketplace add https://github.com/hooni0918/AI-Workflow.git
/plugin install ai-workflow@hooni-workflow
```

이어서 로컬 도구를 맞춥니다. `axe`(시뮬레이터 UI 자동화)·시뮬레이터·빌드 도구를 점검하고 빠진 것만 설치를 제안합니다.

```
/ai-workflow:setup
```

`axe`가 없으면 QA 파이프라인 4단계(시뮬레이터 실행)가 안내만 남기고 멈추므로, QA를 돌릴 사람은 이 단계를 건너뛰지 마세요.

작업 시작은 `/mino` 한 줄입니다 — 진행 상황을 읽어 지금 차례인 세션으로 들어갑니다.

## Contributors

<table>
  <tr align="center">
    <td><b>박병호</b></td>
    <td><b>김유빈</b></td>
    <td><b>이지훈</b></td>
  </tr>
  <tr align="center">
    <td>
      <img src="https://github.com/user-attachments/assets/57e92d6b-356c-4acf-9bf5-38f7f2aa573c" width="200" height="400"><br>
      <a href="https://github.com/hoBahk"><i>hoBahk</i></a>
    </td>
    <td>
      <img src="https://github.com/user-attachments/assets/fb7bdad1-d95a-450a-8da8-8c38ada83451" width="200" height="400"><br>
      <a href="https://github.com/dbqls200"><i>dbqls200</i></a>
    </td>
    <td>
      <img src="https://github.com/user-attachments/assets/65ef658f-55e4-46cc-a70b-ae1ad1c49848" width="200" height="400"><br>
      <a href="https://github.com/hooni0918"><i>hooni0918</i></a>
    </td>
  </tr>
</table>

---

<div align="center">
  <a href="https://hits.sh/github.com/mash-up-kr/Team-MINO-iOS/">
    <img src="https://hits.sh/github.com/mash-up-kr/Team-MINO-iOS.svg" alt="Hits">
  </a>
</div>
