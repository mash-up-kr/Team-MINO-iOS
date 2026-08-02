# DesignSystem

Mino iOS 디자인 시스템 패키지. Figma `MU_Wanted` 디자인 토큰과 컴포넌트를 SwiftUI 로 제공한다.

| 영역 | 진입점 |
|------|--------|
| 타이포그래피 | `MHTypography` (SUITE, 7위계 × Regular/Medium/Bold) — `.mhTypography(_:)` |
| 컬러 | 시맨틱 토큰 `Color.mh*` (라이트/다크 자동 전환) |
| 아이콘 | `MHIcon` (`Icon/Normal/*`) — `Image(_:)` |
| 그림자 | `.mhShadow(...)` |
| 컴포넌트 | `MHButton`, `MHChip`, `MHActionArea`, `MHTextField`, `MHTextArea`, `MHTextButton`, `MHCharacterCounter`, `MHContentBadge`, `MHThumbnail`, `MHAvatar`, `MHAvatarGroup`, `MHAvatarStack`, `MHCategory`, `MHSnackbar`, `MHTooltip`, `MHMenu`, `MHRoomHeader`, `MHFilterBar`, `MHComment`, `MHHomeCard`, `MHCheckbox`, `MHRoomThumbnail`, `MHRoomCard` |

각 토큰·컴포넌트의 상세 사용법은 소스 상단 주석과 public API Quick Help(`///`)를 참조한다.

---

## ⚠️ 폰트 적용 규칙 (중요)

> **입력 필드(TextField 등)에는 SUITE(`MHTypography`)를 쓰지 않고 시스템 폰트를 쓴다.**
> 그 외 모든 텍스트(라벨·버튼·본문·타이틀 등)는 `.mhTypography(...)` (SUITE)를 그대로 유지한다.

### 왜

번들된 SUITE 폰트는 cmap(문자→글리프 매핑)엔 한글 11,172자를 모두 등록해두고도 **실제 윤곽선이 있는
글리프는 약 2,668자뿐**이다. 나머지 ~8,500 음절(예: `볷`(U+BCF7)·`짂`(U+C9C2)·`놝`(U+B19D))은
윤곽선이 없는 빈 글리프라 화면에 **빈칸으로 렌더**된다.

cmap 이 "커버한다"고 주장하기 때문에 **iOS(CoreText)·Android 둘 다 시스템 폰트 폴백이 걸리지 않는다**
(iOS 재현 확인 완료). 특히 입력 중 한글 조합 중간 상태(`벼` → `볷` → `벼지`)에서 이런 음절이 잠깐
나타나면, **사용자가 입력한 글자가 사라진 것처럼** 보인다 — 닉네임·채팅 등 자유 입력에서 재현된다.

시스템 폰트의 한글 폴백(Apple SD Gothic Neo)은 완성형 전체를 커버하므로 이 문제가 없다.

### 어떻게

```swift
// 입력 필드 — 시스템 폰트 (SUITE 미적용)
TextField("닉네임", text: $name)
    .font(.system(size: 16))   // 또는 폰트 미지정

// 그 외 텍스트 — MHTypography(SUITE) 유지
Text("프로필").mhTypography(.heading1Bold)
```

새 화면에 입력 요소가 생기면 이 규칙을 적용한다.

> 이 이슈는 2026-07-29 디자인팀에 전달됨(폰트 자체 수정 검토 중).
> **SUITE 폰트가 완성형 글리프를 모두 포함하도록 고쳐지면 이 예외는 재검토**한다.
