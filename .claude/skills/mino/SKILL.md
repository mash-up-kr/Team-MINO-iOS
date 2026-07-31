---
name: mino
description: Mino iOS 작업의 단일 진입점. 진행 상황을 읽어 지금 차례인 ios-workflow 세션으로 들어간다. "mino", "이어서 하자", "다음 단계", 기획서·피그마를 던지며 작업을 시작할 때 사용한다.
argument-hint: "[처음이면 figma URL 또는 기획서 경로 / 이어서면 비워둠]"
---

# Mino 진입점

`/ios-workflow <세션> <모드>` 를 매번 손으로 적는 대신, 새 창에서 `/mino` 한 줄로 지금 차례인 세션에 들어간다.
**세션을 합치지 않는다** — 창을 나눠 여는 컨텍스트 격리는 그대로 두고, 어느 세션인지 고르는 일만 대신한다.

## 절차

### 1. 진행 상황 판정

`/plan/` 을 탐색해 어느 세션까지 끝났는지 읽는다. 폴더가 없으면 아직 시작 전이다.

| 관측 | 다음 세션 |
|---|---|
| `/plan/` 없음 | **BG** (자료를 인자로 받는다) |
| `background/` 있고 `pr{N}/` 없음 | **BG 이어서** 또는 **MARKUP** |
| `pr{N}/consumable/overview.md` 있고 `persistent/implementation.md` 없음 | **PR_{N}_PLAN 이어서** |
| `pr{N}/persistent/implementation.md` 있고 구현 커밋 없음 | **PR_{N}_IMPL** |
| 구현 커밋 있고 `pr{N}/consumable/pr-body.md` 없음 | **PR_{N}_WRITING** |

산출물이 서로 어긋나 판정이 갈리면 **추측하지 않는다.** 관측한 파일 목록과 후보 세션을 제시하고 사용자에게 고르게 한다.

`MARKUP` 은 PR 세션과 병렬로 도는 별도 트랙이라 위 순서에 끼지 않는다. 화면 마크업이 필요한데 아직 없으면 함께 안내한다.

### 2. 모드 확인

`실무`(피그마가 디자인 진실 원천) / `개인`(피그마 없음, 사용자 시각 확인이 진실 원천).

- 처음이면 **사용자에게 묻는다.** 폴더 구조나 파일 존재로 추론하지 않는다 — 분기 영향이 커서 오추론 비용이 크다.
- 답을 받으면 `/plan/background/retained/mode.md` 에 한 줄로 남긴다.
- 이후 세션에서는 그 파일을 읽되, **진입 안내에 모드를 함께 출력해** 사용자가 한 마디로 뒤집을 수 있게 한다.

### 3. 세션 진입

판정한 세션의 절차를 **직접 읽어 따른다.**

1. ios-workflow 스킬을 Skill tool 로 호출한다 — 스킬 목록에 `ios-workflow`(전역 설치)가 있으면 그 이름으로, `ai-workflow:ios-workflow`(플러그인 설치)만 있으면 그 이름으로. 「세션」 표, 「[CRITICAL] 지킬 원칙」이 여기서 로드된다.
2. 로드된 SKILL.md 의 「작업 진행 순서」에서 자기 세션의 step 파일을 찾아, 스킬 디렉토리 기준 상대 경로로 **전체를 Read** 한다.
3. step.md 도입부의 `[CRITICAL]`·필수 절차부터 실행한다. Plan mode 표기가 있는 step(step-3·step-4)은 `EnterPlanMode` 를 명시 호출한다.

두 이름 다 스킬 목록에 없으면 진행하지 말고 설치를 안내한다: `/plugin marketplace add hooni0918/AI-Workflow` → `/plugin install ai-workflow@hooni-workflow`.

### 4. 진입 보고

무엇을 보고 그렇게 판정했는지 한 줄로 밝힌 뒤 시작한다. 사용자가 틀렸다고 하면 즉시 멈추고 다시 고른다.

```
/plan/pr1/persistent/implementation.md 확인 → PR_1_IMPL 차례입니다 (모드: 실무).
아니면 알려주세요.
```

## 하지 않는 것

- **여러 세션을 한 창에서 연달아 돌지 않는다.** 한 세션이 끝나면 다음 세션 안내를 출력하고 종료한다 — 새 창에서 다시 `/mino`.
- 모드를 추론하지 않는다.
- ios-workflow 의 절차를 여기에 베껴 적지 않는다. 이 파일은 **어느 세션인지 고르는 일**만 하고, 무엇을 어떻게 할지는 ios-workflow 가 단일 출처다.
