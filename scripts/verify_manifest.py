#!/usr/bin/env python3
"""접근성 매니페스트·QA 시나리오의 런타임 정합 검사 (결정론적 게이트).

mino-qa 파이프라인의 접근성 단계 직후에 돈다. accessibility-auditor 가 낸
매니페스트가 "말로만" 식별자를 나열한 게 아니라 **실제 소스에 반영됐는지**를
grep 으로 확정한다 — 이게 통과해야 뒤의 빌드·시뮬레이터 비용을 치를 가치가 있다.

check_consistency.py 와 역할이 다르다:
  - check_consistency.py : 저장소 산출물 자체의 정적 정합 (CI, 앱 소스 없음)
  - 이 스크립트          : 파이프라인이 방금 만든 매니페스트 ↔ 앱 소스의 런타임 정합 (sync 후 본체 cwd)

검사:
  1. 매니페스트(qa/manifests/<Screen>.json)의 각 id 가 실제 .swift 소스에
     `"<id>"` 문자열로 존재하는가 (accessibilityIdentifier 에 반영됐는가).
  2. QA 시나리오(qa/scenarios/*.txt)의 모든 `--id <selector>` 가 어떤 매니페스트에든
     등록돼 있는가 (test-author 가 존재하지 않는 선택자로 시나리오를 짜지 않았는가).

사용:
  python3 scripts/verify_manifest.py [SCREEN ...]      # SCREEN 지정 시 그 매니페스트 존재를 강제
  python3 scripts/verify_manifest.py --root /path/to/app
  옵션: --root(기본 cwd) · --manifests(기본 qa/manifests) · --scenarios(기본 qa/scenarios) · --src(기본 root)

위반 시 file:line(또는 file) 형식으로 출력하고 exit 1. 위반 없으면 조용히 exit 0.
"""
import argparse
import json
import re
import sys
from pathlib import Path

SWIFT_SKIP_DIRS = {".git", ".build", "DerivedData", "qa", "qa-artifacts"}
ID_IN_SCENARIO = re.compile(r"--id\s+(['\"]?)([\w.\-]+)\1")

violations = []


def add(loc, message):
    violations.append(f"{loc}: {message}")


def load_manifest_ids(manifest_path):
    """매니페스트에서 id 목록을 뽑는다. [{"id": ...}] 또는 [ "..." ] 형태를 모두 허용."""
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        add(str(manifest_path), f"매니페스트를 읽/파싱할 수 없음 ({e})")
        return []
    ids = []
    if isinstance(data, list):
        for item in data:
            if isinstance(item, dict) and "id" in item:
                ids.append(str(item["id"]))
            elif isinstance(item, str):
                ids.append(item)
    return ids


def iter_swift(src_root):
    for p in src_root.rglob("*.swift"):
        if any(part in SWIFT_SKIP_DIRS for part in p.parts):
            continue
        if p.is_file():
            yield p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("screens", nargs="*", help="검사할 화면명(매니페스트 파일명 stem). 지정하면 그 매니페스트 존재를 강제한다.")
    ap.add_argument("--root", default=".")
    ap.add_argument("--manifests", default=None)
    ap.add_argument("--scenarios", default=None)
    ap.add_argument("--src", default=None)
    args = ap.parse_args()

    root = Path(args.root).resolve()
    manifests_dir = Path(args.manifests).resolve() if args.manifests else root / "qa" / "manifests"
    scenarios_dir = Path(args.scenarios).resolve() if args.scenarios else root / "qa" / "scenarios"
    src_root = Path(args.src).resolve() if args.src else root

    # 존재하는 모든 매니페스트를 한 번 읽어 전역 id 집합을 만든다 — 시나리오의 --id 는 배치의 어느
    # 매니페스트에든 있으면 되므로(화면 순차 실행 중 앞 화면 시나리오가 뒤 화면 매니페스트를 참조하지 않는다),
    # 특정 화면만 검사할 때도 시나리오 대조는 전역 집합으로 한다. 그러지 않으면 다른 화면 시나리오가 거짓 위반.
    all_ids = set()
    present = {}  # path -> ids
    if manifests_dir.is_dir():
        for mp in sorted(manifests_dir.glob("*.json")):
            ids = load_manifest_ids(mp)
            present[mp] = ids
            all_ids.update(ids)

    # 소스 실재 검사(check 1)의 대상: 지정된 화면(존재 강제) 또는 존재하는 전부.
    if args.screens:
        target_paths = []
        for screen in args.screens:
            mp = manifests_dir / f"{screen}.json"
            if not mp.exists():
                add(str(mp), f"화면 '{screen}' 의 매니페스트가 없음 — 접근성 단계가 파일을 남기지 않았다")
            else:
                target_paths.append(mp)
    else:
        target_paths = sorted(present.keys())

    # ---- 1. 매니페스트 id 가 소스에 반영됐는가 ----
    swift_text = None  # 지연 로딩 (검사 대상 id 가 하나도 없으면 소스를 읽지 않는다)
    for mp in target_paths:
        ids = present.get(mp) or load_manifest_ids(mp)
        if ids and swift_text is None:
            swift_text = "\n".join(p.read_text(encoding="utf-8", errors="ignore") for p in iter_swift(src_root))
        for ident in ids:
            if f'"{ident}"' not in (swift_text or ""):
                add(str(mp), f"식별자 '{ident}' 가 어떤 .swift 소스에도 `\"{ident}\"` 로 존재하지 않음")

    # ---- 2. 시나리오의 --id 가 (어느) 매니페스트에 등록됐는가 ----
    if scenarios_dir.is_dir():
        for scenario in sorted(scenarios_dir.glob("*.txt")):
            for i, line in enumerate(scenario.read_text(encoding="utf-8").splitlines(), start=1):
                for m in ID_IN_SCENARIO.finditer(line):
                    selector = m.group(2)
                    if selector not in all_ids:
                        add(f"{scenario}:{i}", f"시나리오의 --id '{selector}' 가 어떤 매니페스트에도 없음")

    if violations:
        for v in violations:
            print(v)
        print(f"\n{len(violations)}건 위반", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
