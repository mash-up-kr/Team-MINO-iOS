# Project Guidelines

## Architecture

이 프로젝트는 Clean Architecture + DDD를 따른다. 상세 규칙은 아래 문서를 참조한다.

@.claude/docs/clean-architecture.md

화면 아키텍처(MVI + Coordinator + DI)의 구조·사용법·확장 방향은 아래 문서를 참조한다.

@.claude/docs/mvi-coordinator-di.md

## Design System

디자인 시스템(타이포·컬러·아이콘·그림자·컴포넌트)의 진입점과 사용 규칙은 아래 문서를 참조한다.

@Packages/DesignSystem/README.md

- **폰트 규칙(중요)**: 입력 필드(TextField 등)는 시스템 폰트를 쓰고, 그 외 텍스트만 `MHTypography`(SUITE)를 쓴다. SUITE 는 한글 ~8,500 음절이 빈 글리프라 입력 중 글자가 사라져 보이기 때문 — 상세는 위 README.
- **컴포넌트 재사용 필수**: 피그마 디자인을 구현할 때, 화면 요소가 DS 패키지의 기존 `MH*` 컴포넌트와 매칭되면 **반드시 그것을 사용**한다. 인라인으로 직접 만들지 않는다. 매칭 여부는 위 README의 컴포넌트 목록과 소스 public API를 확인한다.
