# Networking

HTTP 통신 인프라. **화면에 API 를 붙이는 절차는 [`Docs/AddingAPI.md`](Docs/AddingAPI.md) 를 따른다.**

내부 구현은 Alamofire 지만 **패키지 밖으로 노출하지 않는다** — 바깥 레이어는 `HTTPClient` 프로토콜만 본다.

| 영역 | 진입점 |
|------|--------|
| 요청 정의 | `Endpoint<Response>` — path·method·query·headers·body·auth·timeout |
| 호출 | `HTTPClient.request(_:)` / 목록은 `requestPage(_:)` |
| 목록 응답 | `Page<Element>` (`items` + `pagination`) |
| 빈 성공 응답 | `OkResponse` |
| 오류 | `NetworkError` — 4xx 는 `errorCode`·`message` 동봉. 전송 실패의 `TransportFailure` 는 **갈래가 완전하지 않다**(셀룰러 차단·TLS 실패는 `.unknown`) — 주 용도는 로그 |
| 디코딩·인코딩 규칙 | `APIDecoder` · `APIEncoder` |
| 세션 기본값 | `Session.mino()` — 타임아웃·재시도·캐시·로깅이 여기 묶여 있다 |

---

## 문서

| | |
|---|---|
| [`Docs/AddingAPI.md`](Docs/AddingAPI.md) | 새 API 붙이는 절차 7단계 · 페이지네이션 · `Page` 의 Domain 경계 규칙 |
| 아래 | 파일 배치 · 금지 · 인증 · 배선 · 동작 기본값 |

---

## 파일 배치

```
Packages/Data/Sources/Data/
  API/            RoomAPI.swift · PinAPI.swift …      ← 엔드포인트 정의
  DTO/            RoomDTO.swift · PinDTO.swift …      ← 서버 스키마
  Repositories/   RoomRepositoryImpl.swift …          ← 조립 + 매핑
```

---

## 금지

| 금지 | 이유 |
|---|---|
| `import Alamofire` (Networking 밖에서) | 라이브러리 격리가 깨지고 교체가 불가능해진다. **아직 리뷰로만 지킨다** — `layer-guard` 에 grep 검사를 넣는 건 후속(토큰 권한) |
| `JSONDecoder()` 직접 생성 | 날짜 전략이 갈린다. 디코딩은 클라이언트가 한다 |
| Entity 에 `Codable` 부착 | Domain 이 API 스키마와 결합된다 |
| DTO 를 `public` 으로 | Domain 으로 샌다 |
| envelope 래퍼 DTO | 클라이언트가 이미 벗긴다 |
| Repository 에서 `NetworkError` 를 그대로 던지기 | Domain 이 인프라를 알게 된다 |
| Repository 안에서 `Endpoint(...)` 직접 생성 | 경로가 흩어진다. 반드시 `Data/API/` 의 `enum` 을 거친다 |
| 오류를 **케이스로만** 분기 | 같은 404 가 `.notFound` 로도 `.unexpectedErrorFormat(404,_)` 로도 온다. `error.statusCode` 를 축으로 쓴다 |
| 번역 안 된 오류를 조용히 `.unknown` 으로 | 어떤 `DomainError` 를 추가해야 하는지 알 단서가 사라진다. `default` 에 로그를 남긴다 |
| 오류를 `String(describing:)` 으로 로그에 찍기 | 연관값의 서버 원문 `message`·에러 본문 `preview` 가 릴리즈 기기 로그에 평문으로 남는다(`OSLogger` 는 `.public`, 릴리즈 최소 레벨은 `warning`). 케이스 이름만 주는 `error.label` 을 쓴다 |

---

## 인증

**대부분의 API 는 토큰이 필요하다.** 서버 인증은 두 단계이고(① 토큰 검증 ② 그 uid 로 회원이
등록됐는지 확인), 엔드포인트마다 어디까지 거치는지가 다르다 — `AuthRequirement` 3상태다.

| | ① 토큰 검증 | ② 회원 등록 확인 | |
|---|---|---|---|
| `.full`(기본) | ✓ | ✓ | 대부분의 API |
| `.unregisteredUser` | ✓ | — | `POST /api/v1/users` |
| `.none` | — | — | `GET /api/v1/invitations/{code}` |

```swift
Endpoint(path: "api/v1/users", method: .post, body: .json(dto), auth: .unregisteredUser)
Endpoint(path: "api/v1/invitations/\(code)", auth: .none)
```

⚠️ **`.unregisteredUser` 에 토큰을 빼면 안 된다.** 서버가 토큰의 uid 로 누구를 등록할지 정하므로,
빼면 최초 진입의 회원 등록이 통째로 실패한다(실측: 토큰 없이 부르면 "인증 정보가 없습니다",
유효한 토큰이면 "등록되지 않은 유저입니다").

토큰은 **`AuthTokenProvider`** 가 공급한다. Networking 은 인증 수단을 알지 못하고, 앱이 구현을 주입한다
(현재 구현은 Firebase 익명 인증 — `App/Sources/Auth/FirebaseAuthTokenProvider.swift`).

```swift
URLSessionHTTPClient(baseURL: url, tokenProvider: FirebaseAuthTokenProvider())
```

- **토큰이 있으면 모든 요청에 `Authorization: Bearer <토큰>` 이 붙는다** — `auth` 로 거르지 않는다.
  `.none` 이어도 서버가 인증을 타지 않아 무해하고, `.unregisteredUser` 는 토큰이 반드시 필요하다
- **호출부가 `headers` 로 넘긴 `Authorization` 이 이긴다** (토큰 주입이 먼저 일어난다)
- 401 을 받으면 토큰을 **강제 갱신해 1회만** 재시도한다. 평소엔 여기까지 오지 않는다 —
  공급자가 만료 임박분을 알아서 갱신하기 때문이다(기기 시계 오차 대비 안전망)
- 토큰을 못 얻으면 `Authorization` 없이 나가고 서버가 401 을 준다. "토큰이 없다" 와
  "서버가 거부했다" 를 한 갈래로 모아 화면이 재인증 하나만 보게 한다

⚠️ **`tokenProvider` 를 넘기지 않으면 인증 없이 나간다.** 실 클라이언트를 조립할 때 빠뜨리면
인증이 필요한 API 가 전부 401 을 받는데, 컴파일은 통과하므로 조용히 깨진다.

---

## 배선

클라이언트는 `App/Sources/AppDependencies.swift` 에서 **한 번만** 만들어 공유한다.

```swift
let httpClient: HTTPClient
private static let baseURL = URL(string: "https://api.gguk.org")!

self.httpClient = URLSessionHTTPClient(baseURL: Self.baseURL, tokenProvider: FirebaseAuthTokenProvider())
```

Repository 구현은 이 `httpClient` 를 받는다 — 새로 만들지 않는다.

```swift
self.fetchRooms = DefaultFetchRoomsUseCase(repository: RoomRepositoryImpl(client: httpClient))
```

**서버가 하나라 환경 분기가 없다.** 주소를 xcconfig 로 빼지도 않았다 — 관리 대상이 값 하나뿐이라
장치 비용이 더 크다. 로컬·스테이징이 생기면 그때 `AppDependencies.baseURL` 을 출발점으로 분기한다
(`http` 로컬 서버를 쓰게 되면 `NSAllowsLocalNetworking` ATS 예외가 함께 필요하다).

---

## 아직 없는 것

| | 상태 |
|---|---|
| 파일·이미지 업로드 | 스펙에 업로드 엔드포인트가 없다. 계약 확정 후 |
| 429 `Retry-After` 존중 | 429 가 스펙에 정의되면 |

## 동작 기본값

| | 값 |
|---|---|
| 요청 타임아웃 | 10초 (`Endpoint.timeout` 으로 개별 상향 가능) |
| 재시도 | Alamofire 기본값 — 상태코드 `408·500·502·503·504`(501·505 제외), 메서드 GET·PUT·DELETE·HEAD·OPTIONS·TRACE(POST·PATCH 제외)에 **1회** |
| 캐시 | 끔 — `requestCachePolicy` 로 읽기를 막고 **`urlCache = nil` 로 저장도 막는다**(정책만으로는 디스크에 계속 쌓인다) |
| 기본 헤더 | `Accept: application/json` 항상, `Content-Type: application/json` 은 body 있을 때만 |
| 로그(릴리즈) | 실패·재시도만 남는다. **경로의 식별자는 `***` 로 가려지고 응답 본문은 크기만** 남는다 — 초대 코드가 경로에 있고(`/invitations/{code}`) `OSLogger` 가 `.public` 으로 찍어 기기에 영구 기록되기 때문 |
| 로그(DEBUG) | 전체 URL·응답 본문 앞 200바이트까지. `Authorization` 은 어느 빌드에서도 찍지 않는다 |

⚠️ **경로 세그먼트 이름을 지을 때**: 마스킹은 "6자 이상 + 숫자 포함 + 영숫자" 를 식별자로 보는
휴리스틱이라, `oauth2`·`v2beta` 같은 **고정 경로 이름도 가려진다.** 그러면 릴리즈 로그에서
어느 API 인지 알 수 없어진다 — 그런 이름을 쓰게 되면 `LogRedaction` 에 예외를 추가한다.
