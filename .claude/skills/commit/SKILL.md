---
name: commit
description: 팀 커밋 컨벤션(Conventional Commits, 한글 제목, 레이어 scope)에 맞춰 변경사항을 작업 단위로 분리해 커밋한다. 사용자가 "커밋", "commit", "커밋해줘"라고 하거나 변경을 저장소에 기록하려 할 때 사용한다.
---

# 커밋 스킬

변경사항을 **팀 커밋 컨벤션에 맞는 메시지**로, **작업 단위로 분리**해 커밋한다.
계획을 따로 승인받지 않고 **바로 커밋**한다.

## 워크플로

1. **현재 상태 파악** — 아래를 병렬로 실행한다.
   - `git status`
   - `git diff`(unstaged) / `git diff --cached`(staged)
   - `git log --oneline -10` (최근 커밋 형식 참고)
2. **원격 동기화 (커밋 전 필수)** — 커밋하기 전에 원격에 새 커밋이 있는지 확인하고 통합한다. 아래 "원격 동기화" 절차를 따른다. **충돌이 나면 커밋을 진행하지 말고 멈춰 사용자에게 보고한다.**
3. **작업 단위로 분리** — 변경을 논리적 단위로 그룹핑한다. 서로 다른 관심사(예: 기능 추가 + 오타 수정 + 설정 변경)는 **별도 커밋으로 나눈다**. 한 커밋 = 한 가지 목적.
4. **선택적 스테이징** — 각 단위에 해당하는 파일만 `git add <paths>`로 스테이징한다. 한 파일 안에 여러 관심사가 섞여 있으면 `git add -p`로 hunk 단위로 나눈다.
5. **커밋 생성** — 아래 형식에 맞는 메시지로 `git commit` 한다. 여러 단위면 4~5를 반복한다.
6. **결과 보고** — 생성한 커밋들을 `git log --oneline`으로 확인해 사용자에게 보여준다.

> 커밋을 만들되 **push는 하지 않는다**. push는 사용자가 명시적으로 요청할 때만 한다.

## 원격 동기화

커밋 전에 원격 브랜치가 앞서 있는지 확인하고, 앞서 있으면 로컬 변경을 보존한 채 통합한다.

1. **원격 최신화** — `git fetch`.
2. **업스트림 비교** — `git rev-list --left-right --count @{u}...HEAD` 로 behind/ahead 개수를 센다.
   - 업스트림이 설정돼 있지 않으면(`@{u}` 없음) 이 절차를 건너뛴다.
   - behind가 0이면 원격에 새 커밋이 없으므로 바로 커밋 단계로 넘어간다.
3. **통합 (behind > 0일 때)** — 원격에 푸시된 새 커밋이 있으므로 pull 한다.
   - 작업 트리에 커밋 안 된 변경이 있으면 먼저 `git stash push -u` 로 안전하게 보관한다.
   - `git pull --rebase` 로 원격 커밋 위에 재배치한다.
   - stash 했다면 `git stash pop` 으로 되돌린다.
4. **충돌 확인** — pull/rebase 또는 stash pop에서 충돌이 나면:
   - **커밋을 진행하지 않는다.**
   - `git status` 로 충돌 파일 목록을 확인해 사용자에게 그대로 보고하고, 해결 방법을 안내한 뒤 멈춘다.
   - rebase 중이라면 필요 시 `git rebase --abort` 로 원상복구할 수 있음을 함께 알린다.
5. **충돌 없음** — 깨끗하게 동기화됐으면 커밋 단계로 진행한다.

## 메시지 형식

```
type(scope): 한글 요약

(선택) 본문 — 무엇을 왜 바꿨는지. 상세 변경은 불릿으로.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

### 제목 줄 (필수)
- 형식: `type(scope): 요약` — scope는 **괄호로 반드시 붙인다**.
- 요약은 **한글**, 명령형/개조식. 마침표로 끝내지 않는다.
- 50자 내외로 간결하게. `(#PR번호)`는 **붙이지 않는다** (GitHub 스쿼시 머지가 자동 추가).

### type (11종)
| type | 용도 |
|------|------|
| `feat` | 새로운 기능 추가 |
| `fix` | 버그 수정 |
| `docs` | 문서만 변경 (README, 주석 등) |
| `style` | 동작 변화 없는 포맷팅 (공백, 세미콜론, 들여쓰기) |
| `refactor` | 기능 변화 없는 코드 구조 개선 |
| `perf` | 성능 개선 |
| `test` | 테스트 추가/수정 |
| `build` | 빌드 시스템·의존성 변경 (SPM, Xcode 설정) |
| `ci` | CI 설정 변경 (.github/workflows) |
| `chore` | 기타 잡무 (설정, 도구, 잡일) |
| `revert` | 이전 커밋 되돌리기 |

### scope (필수, 괄호로)
변경이 일어난 **위치(모듈/레이어)**를 적는다. type이 "무엇을 했나"라면 scope는 "어디를 건드렸나"다.

권장 scope — 이 프로젝트의 SPM 모듈/레이어명:
`Domain` · `Data` · `Feature` · `Core` · `Networking` · `DesignSystem` · `App` · `CI` · `Claude` · `Deps`

- 변경이 한 모듈에 속하면 그 모듈명을 쓴다: `feat(Domain):`, `fix(Data):`.
- `.github/workflows` 변경은 `CI`, `.claude/` 변경은 `Claude`, 의존성/패키지 매니페스트는 `Deps`.
- 변경이 여러 모듈에 **넓게 걸쳐** 있어 하나로 특정하기 어려우면 가장 대표적인 상위 관심사를 scope로 쓴다(예: 전면 리팩터링은 `refactor(App):`). 억지로 나열하지 않는다.

### 본문 (비자명할 때만)
- **기본은 생략.** 제목만으로 무엇을/왜가 충분히 드러나는 사소한 변경(오타, 포맷, 단순 설정)은 본문을 쓰지 않는다.
- 변경 의도나 배경이 제목만으로 자명하지 않을 때만 본문을 추가한다. 이때는 **"왜"**(배경·이유)를 우선 설명하고, 상세 변경 목록은 불릿으로 정리한다.
- 검증을 수행했다면 마지막에 `검증: ...` 한 줄을 남겨도 좋다(예: `검증: iOS 시뮬레이터 빌드 성공, Domain swift test 통과`).

### 푸터
- 커밋 메시지 끝에 항상 다음 트레일러를 붙인다:
  ```
  Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
  ```

## 예시

제목만 (본문 생략):
```
fix(Data): DTO 디코딩 실패 시 unknown 도메인 오류로 매핑

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

본문 포함 (비자명):
```
refactor(App): 컴포지션 루트에서만 구체 타입을 조립하도록 분리

Feature가 Data/Networking 구현을 직접 알던 구조를 끊고, 의존성 조립을
AppDependencies 한 곳으로 모아 레이어 경계를 명확히 했다.

- MemberViewController에 UseCase를 주입받도록 변경
- Repository 구현체 생성을 AppDependencies로 이동

검증: iOS 시뮬레이터 빌드 성공

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

## 주의
- 커밋 메시지는 `git commit -m $'...\n\n...'` 또는 HEREDOC으로 줄바꿈을 보존해 작성한다.
- 이미 스테이징된 것과 아닌 것을 구분해, 사용자가 의도치 않은 파일이 섞이지 않게 한다.
- 관련 없는 변경을 한 커밋에 몰아넣지 않는다. 의심되면 나눈다.
