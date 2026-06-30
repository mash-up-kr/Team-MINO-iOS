#!/bin/sh
# Xcode Cloud가 레포 클론 직후 실행하는 훅.
# Xcode Cloud는 .xcodeproj와 같은 디렉터리의 ci_scripts/ 만 인식하고,
# 그 ci_scripts/ 를 작업 디렉터리(root)로 잡는다 → 이 파일은 App/ci_scripts/ 에 둔다.
#
# 호스트(macOS)에서 빌드 가능한 패키지의 swift test를 돌려 PR/푸시 안전망으로 쓴다.
# 제외 패키지:
#   - Networking / Data : iOS 전용 async URLSession API(macOS 12+ 미지원)라 호스트 swift test 불가
#   - DesignSystem      : UIKit 의존
#   → 위 3개는 App 스킴의 시뮬레이터 빌드에서 컴파일 검증된다.

set -e

# 작업 디렉터리는 App/ci_scripts/ 이므로 레포 루트로 이동해 Packages/ 를 찾는다.
cd "${CI_PRIMARY_REPOSITORY_PATH:-$(dirname "$0")/../..}"

PACKAGES="MVI FlowCoordination Feature Core Domain"

for pkg in $PACKAGES; do
  echo "▸ swift test — $pkg"
  swift test --package-path "Packages/$pkg"
done

echo "✅ 패키지 테스트 전부 통과"
