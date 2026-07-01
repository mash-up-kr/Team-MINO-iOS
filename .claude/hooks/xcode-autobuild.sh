#!/bin/bash
#
# Claude Code Xcode 자동 빌드 훅
#
# 코드 수정 작업이 끝나면, 수정한 파일이 속한 Xcode 프로젝트를 찾아
# Xcode에서 열고 빌드(실행 대상이 있으면 실행)한다.
#
# 사용법:
#   xcode-autobuild.sh mark    # PostToolUse(Edit|Write): 수정 파일이 속한 프로젝트를 기록
#   xcode-autobuild.sh build   # Stop: 기록된 프로젝트를 Xcode에서 열고 빌드/실행
#
# 동작 개요:
#   - mark  : stdin 으로 들어온 tool_input.file_path 를 읽어, 빌드 대상 확장자
#             (.swift/.pbxproj/.xcstrings/.plist)면 프로젝트를 찾아 FLAG 파일에 기록.
#             프로젝트 탐색은 파일에서 상위로 올라가며 찾고, 못 찾으면 git 저장소
#             루트 하위 전체에서 찾는다(소스가 Packages/*, 프로젝트가 App/ 인 SPM 구조 대응).
#             FLAG 가 이미 있으면 즉시 종료하여 불필요한 파싱 프로세스를 막는다.
#   - build : FLAG 에 기록된 프로젝트를 Xcode 로 열고(이미 열려 있으면 그대로),
#             로딩이 끝나면 진행 중인 실행/빌드를 stop 으로 중단한 뒤 run 을 시도하고,
#             실행 대상(시뮬/기기)이 없어 실패하면 build 로 폴백한다.
#             scheme/destination 은 Xcode 선택 설정을 따른다.

set -euo pipefail

FLAG="/tmp/.claude_build_needed"

# 파일이 속한 가장 가까운 Xcode 프로젝트(.xcworkspace 우선, 없으면 .xcodeproj) 탐색
# 1) 파일에서 상위로 올라가며 탐색 (App/ 내부 수정 등, 프로젝트가 조상 경로에 있을 때)
# 2) 못 찾으면 git 저장소 루트 하위 전체에서 탐색 (SPM 구조: 소스는 Packages/*,
#    프로젝트는 형제 디렉터리 App/ 에 있어 상위 탐색으로는 닿지 않는 경우 대응)
find_project() {
  local dir="$1"
  local ws proj

  # 1) 상위 방향 탐색
  local cur="$dir"
  while [ -n "$cur" ] && [ "$cur" != "/" ] && [ "$cur" != "." ]; do
    ws=$(find "$cur" -maxdepth 1 -name "*.xcworkspace" 2>/dev/null | head -1)
    if [ -n "$ws" ]; then echo "$ws"; return 0; fi
    proj=$(find "$cur" -maxdepth 1 -name "*.xcodeproj" 2>/dev/null | head -1)
    if [ -n "$proj" ]; then echo "$proj"; return 0; fi
    cur=$(dirname "$cur")
  done

  # 2) 저장소 루트 하위 폴백 탐색 (xcodeproj 내부/유저 데이터 워크스페이스는 제외)
  local root
  root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || return 1
  ws=$(find "$root" -name "*.xcworkspace" \
        -not -path "*/xcuserdata/*" -not -path "*/project.xcworkspace" 2>/dev/null | head -1)
  if [ -n "$ws" ]; then echo "$ws"; return 0; fi
  proj=$(find "$root" -name "*.xcodeproj" -not -path "*/xcuserdata/*" 2>/dev/null | head -1)
  if [ -n "$proj" ]; then echo "$proj"; return 0; fi

  return 1
}

case "${1:-}" in
  mark)
    # 이미 빌드 대상이 기록돼 있으면 추가 작업 불필요 → 즉시 종료
    [ -f "$FLAG" ] && exit 0

    FILE_PATH=$(cat | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || true)
    case "$FILE_PATH" in
      *.swift|*.pbxproj|*.xcstrings|*.plist) ;;
      *) exit 0 ;;
    esac

    PROJECT=$(find_project "$(dirname "$FILE_PATH")" || true)
    [ -n "$PROJECT" ] && printf '%s' "$PROJECT" > "$FLAG"
    exit 0
    ;;

  build)
    [ -f "$FLAG" ] || exit 0
    PROJECT=$(cat "$FLAG")
    rm -f "$FLAG"
    [ -n "$PROJECT" ] || exit 0

    /usr/bin/osascript <<OSA 2>/dev/null || true
tell application "Xcode"
  open POSIX file "$PROJECT"
  set deadline to (current date) + 30
  repeat
    try
      if (exists (first workspace document whose path is "$PROJECT" and loaded is true)) then exit repeat
    end try
    if (current date) > deadline then exit repeat
    delay 0.5
  end repeat
  set doc to (first workspace document whose path is "$PROJECT")
  -- 이미 실행/빌드 중이면 먼저 중단하고 새로 시작한다.
  -- (아무것도 안 돌고 있으면 stop 은 무시됨)
  try
    stop doc
  end try
  delay 1
  -- 실행 대상(시뮬레이터/기기)이 선택돼 있으면 run, 없으면 build 로 폴백.
  -- active run destination 속성은 대상이 선택돼 있어도 missing value 를 반환해
  -- 신뢰할 수 없으므로, 검사 대신 run 을 시도하고 실패할 때만 build 한다.
  try
    run doc
  on error
    try
      build doc
    end try
  end try
end tell
OSA
    exit 0
    ;;

  *)
    echo "usage: $0 {mark|build}" >&2
    exit 1
    ;;
esac
