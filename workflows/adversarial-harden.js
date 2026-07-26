// adversarial-harden.js — 병렬 적대 에이전트로 이 번들의 산출물을 단단하게 만드는 워크플로우.
//
// 실행: Claude Code에서 Workflow 툴로 이 스크립트를 돌린다.
//   Workflow({ scriptPath: "workflows/adversarial-harden.js" })                    // cwd가 이 레포일 때
//   Workflow({ scriptPath: ".../adversarial-harden.js", args: "/abs/path/to/repo" }) // 다른 cwd에서 실행할 때
// args로 저장소 절대경로를 넘기면 비평가가 그 경로를 기준으로 파일을 연다. 없으면 cwd 기준.
//
// 한 라운드 = 차원별 비평가가 동시에 산출물을 공격(find) → 각 발견을 독립 검증(verify, refute 우선)
//             → 다수결 생존분만 confirmed로 채택. 사람(또는 메인 에이전트)이 confirmed를 수정에 반영한다.
// "loop-until-dry": 새 발견이 없는 라운드가 2회 연속이면 종료.
//
// 결정론적 정합(호명 오류·죽은 링크·axe 명령 존재·금지 문자열)은 scripts/check_consistency.py가 담당한다.
// 여기 DIMENSIONS는 grep으로 못 잡는 의미론적 판단(약속과 코드의 괴리, 아키텍처 위반 등)만 남긴다.

export const meta = {
  name: 'adversarial-harden',
  description: '이 QA 번들의 에이전트·스킬·README를 차원별 적대 리뷰어로 공격하고, 살아남은 결함만 보고한다',
  phases: [
    { title: 'Find', detail: '차원별 비평가가 동시에 산출물을 공격' },
    { title: 'Verify', detail: '각 발견을 독립 검증 (refute 우선, 다수결)' },
  ],
}

// 저장소 루트. args로 절대경로를 받으면 그 기준, 아니면 cwd 기준.
const ROOT = (typeof args === 'string' && args.trim()) ? args.trim() : '.'

// 스캔 범위 지시 — find·verify 양쪽에 공통으로 붙인다.
// ROOT가 cwd와 다를 때(예: 다른 레포를 args로 지정) 에이전트가 cwd에서 grep을 돌리면
// 엉뚱한 레포를 스캔해(거대 모노레포면 수십 분) 파일을 못 찾고 헛-판정한다. 그래서 경로를
// ROOT로 못박고, ROOT 밖을 스캔하지 못하게 한다.
const SCOPE = `모든 경로는 루트 ${ROOT} 기준이다. Read/Grep/Glob 은 반드시 이 루트 안에서만 수행하고 ` +
  `(예: Grep 의 path 인자에 ${ROOT} 를 준다), 루트 밖(상위 디렉터리·다른 레포·cwd)은 절대 스캔하지 마라. ` +
  `상대 경로가 주어지면 ${ROOT} 를 앞에 붙여 절대경로로 연다.`

// 공격 차원. 각 비평가는 자기 차원만 본다 — 한 명이 모든 걸 보는 것보다 빈틈이 적다.
const DIMENSIONS = [
  { key: 'harness-truth',  prompt: 'mino-qa/SKILL.md, README.md, docs/*.md 가 약속하는 게이트·산출물·흐름(예: "식별자 0개면 멈춤", "빌드 실패면 게이트", "qa/manifests/*.json로 저장")을 .claude/agents/*.md 의 실제 지시와 대조하라. 문서만 약속하고 에이전트가 안 지키는 것, 에이전트에 있는데 문서가 모르는 것을 찾아라. 에이전트 본문이 호명한 도구(특히 mcp__* )가 자기 frontmatter 의 tools 허용목록에 실제로 있는지도 본다 — 없으면 그 절차는 실행 자체가 불가능하다.' },
  { key: 'mino-arch-fit',  prompt: 'CLAUDE.md 의 Clean Architecture 레이어 규칙(Domain은 바깥 모름, DTO 비노출, Protocol 의존)에 비춰 에이전트들이 레이어 경계를 위반하도록 유도하는 지점을 찾아라. 예: test-author가 Domain에 Data를 끌어들이게 하는 안내.' },
  { key: 'a11y-coverage',  prompt: 'accessibility-auditor 가 로딩/빈/에러 상태, 리스트 행, 토글 등 자동화에 필요한 요소를 빠뜨릴 수 있는 구멍을 찾아라. 식별자 네이밍이 표시 텍스트에 결합되는 위험도 본다.' },
  { key: 'test-quality',   prompt: 'test-author 가 플레이키 테스트, 병렬 비안전 테스트, 트리비얼 테스트를 만들도록 유도하는 지점을 swift-testing-expert/swift-concurrency 기준으로 찾아라.' },
]

const FINDINGS = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          file: { type: 'string' },
          detail: { type: 'string' },
          fix: { type: 'string' },
          severity: { type: 'string', enum: ['high', 'medium', 'low'] },
        },
        required: ['title', 'file', 'detail', 'fix', 'severity'],
      },
    },
  },
  required: ['findings'],
}

const VERDICT = {
  type: 'object',
  properties: {
    refuted: { type: 'boolean' },
    reason: { type: 'string' },
  },
  required: ['refuted', 'reason'],
}

// 검증 렌즈 — 3명이 같은 프롬프트로 보면 표가 상관돼 다수결이 무의미하다(Find가 차원을 나눈 것과 같은 이유).
// 각 렌즈는 다른 각도에서 결함을 죽이려 든다. refuted=true 는 "이 결함은 조치할 가치가 없다"는 킬 표.
// 세 렌즈 중 2표 이상이 살려야(refuted=false) confirmed — 사실이고, 사소하지 않고, 수정이 안전한 것만 통과.
const LENSES = [
  {
    key: 'fact',
    prompt: '이 주장이 파일 근거로 **사실인가**를 검증하라. 실제 파일을 직접 열어 주장이 틀렸음(근거가 코드와 다름)을 보이면 refuted=true. 사실로 확인되면 refuted=false.',
  },
  {
    key: 'severity',
    prompt: '주장이 사실이라 가정하고 **심각도가 조치할 가치가 있는가**를 검증하라. 실제 영향이 미미하거나(로그 노이즈·이론적) 이미 다른 게이트가 막고 있으면 과장이므로 refuted=true. 실질 위험이 있으면 refuted=false.',
  },
  {
    key: 'fix-safety',
    prompt: '제안 수정(fix)을 적용했을 때 **다른 게이트·레이어 경계·이 번들의 원칙(커밋 안 함/역할 분리/게이트 의미)을 깨뜨리는가**를 검증하라. 수정이 득보다 실이면 refuted=true. 안전하면 refuted=false.',
  },
]

const key = (f) => `${f.file}::${f.title}`
const seen = new Set()
const confirmed = []
let dry = 0

while (dry < 2) {
  // 이미 검증까지 끝난 발견을 finder에 알려 재보고를 막는다 — title 표현이 라운드마다 흔들려도
  // dedup(key)만으로는 loop-until-dry가 안 마르므로, 본 것을 명시적으로 배제 목록으로 준다.
  const seenList = seen.size ? [...seen].join(' / ') : '(아직 없음)'

  // Find: 차원별 비평가 동시 실행 (배리어 — 이번 라운드 발견을 모두 모은 뒤 dedup)
  const found = (await parallel(DIMENSIONS.map((d) => () =>
    agent(
      `이 저장소(Mino-harness QA 번들)의 산출물을 적대적으로 검토하라. 차원: ${d.key}\n\n${d.prompt}\n\n` +
      `${SCOPE} 실제 파일을 Read/Grep으로 직접 열어 근거를 확인한 결함만 보고하라. 추측 금지. 결함이 없으면 빈 배열.\n\n` +
      `이미 보고돼 검증까지 끝난 결함(file::title) — 표현을 바꿔서라도 재보고하지 말 것:\n${seenList}`,
      { label: `find:${d.key}`, phase: 'Find', schema: FINDINGS }
    )
  ))).filter(Boolean).flatMap((r) => r.findings || [])

  const fresh = found.filter((f) => !seen.has(key(f)))
  if (fresh.length === 0) { dry++; log(`새 발견 0건 (dry ${dry}/2)`); continue }
  dry = 0
  fresh.forEach((f) => seen.add(key(f)))
  log(`이번 라운드 새 발견 ${fresh.length}건 → 검증 진입`)

  // Verify: 각 발견을 렌즈가 다른 검증자 3명이 독립 판정. 2표 이상 생존해야 confirmed.
  const judged = await parallel(fresh.map((f) => () =>
    parallel(LENSES.map((lens) => () =>
      agent(
        `결함 주장을 '${lens.key}' 렌즈로 검증하라. ${lens.prompt}\n\n${SCOPE}\n\n` +
        `주장: ${f.title}\n파일(루트 기준): ${f.file}\n근거: ${f.detail}\n제안수정: ${f.fix}\n심각도: ${f.severity}`,
        { label: `verify:${f.file}#${lens.key}`, phase: 'Verify', schema: VERDICT }
      )
    )).then((votes) => {
      const survive = votes.filter(Boolean).filter((v) => !v.refuted).length
      return { finding: f, survive, real: survive >= 2 }
    })
  ))

  confirmed.push(...judged.filter((j) => j.real).map((j) => j.finding))
}

log(`확정 결함 ${confirmed.length}건`)
return { confirmed }
