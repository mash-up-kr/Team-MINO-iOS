# Networking

HTTP 통신 인프라. **화면에 API 를 붙일 때 이 문서를 따른다.**

내부 구현은 Alamofire 지만 **패키지 밖으로 노출하지 않는다** — 바깥 레이어는 `HTTPClient` 프로토콜만 본다.

| 영역 | 진입점 |
|------|--------|
| 요청 정의 | `Endpoint<Response>` — path·method·query·headers·body·requiresAuth·timeout |
| 호출 | `HTTPClient.request(_:)` / 목록은 `requestPage(_:)` |
| 목록 응답 | `Page<Element>` (`items` + `pagination`) |
| 빈 성공 응답 | `OkResponse` |
| 오류 | `NetworkError` — 4xx 는 `errorCode`·`message` 동봉. 전송 실패의 `TransportFailure` 는 **갈래가 완전하지 않다**(셀룰러 차단·TLS 실패는 `.unknown`) — 주 용도는 로그 |
| 디코딩·인코딩 규칙 | `APIDecoder` · `APIEncoder` |
| 세션 기본값 | `Session.mino()` — 타임아웃·재시도·캐시·로깅이 여기 묶여 있다 |

---

## 새 API 붙이는 절차

`GET /api/v1/rooms`(내가 속한 방 목록)를 예로 든다.

### 1) 엔드포인트 정의 — `Data/API/`

리소스마다 `enum` 하나에 모은다. **Repository 메서드 안에 경로를 인라인하지 않는다.**

> `Data` 는 지금 `Networking` 의존이 없다(쓰는 코드가 없어 선언을 지웠다).
> 첫 Repository 를 만들 때 `Packages/Data/Package.swift` 에 아래를 되돌린다.
> ```swift
> .package(path: "../Networking"),
> .target(name: "Data", dependencies: ["Domain", "Networking"]),
> ```

```swift
// Packages/Data/Sources/Data/API/RoomAPI.swift
import Networking

enum RoomAPI {
    private static let base = "api/v1/rooms"

    static func list(showUsers: Bool = false) -> Endpoint<[RoomDTO]> {
        Endpoint(
            path: base,
            queryItems: showUsers ? [URLQueryItem(name: "showUsers", value: "true")] : []
        )
    }

    static func detail(_ roomId: String) -> Endpoint<RoomDetailDTO> {
        Endpoint(path: "\(base)/\(roomId)")
    }

    static func leave(_ roomId: String) -> Endpoint<OkResponse> {
        Endpoint(path: "\(base)/\(roomId)/members/me", method: .delete)
    }
}
```

- **응답 타입은 `Endpoint` 제네릭에 담는다.** 호출부가 타입을 다시 적지 않으므로 어긋날 수 없다
- 제네릭 파라미터는 **`data` 안쪽 알맹이**다. envelope(`{"data": ...}`)은 클라이언트가 벗긴다
- `base` 상수로 경로 조각을 묶어 같은 리소스 경로가 흩어지지 않게 한다

### 2) DTO 작성 — `Data/DTO/`

리소스 단위로 한 파일에 모은다(`RoomDTO.swift` 에 `RoomDTO`·`RoomMemberDTO` 함께).

```swift
struct RoomDTO: Decodable {          // internal — Domain 에 노출 금지
    let id: String
    let name: String
    let description: String?
    let createdAt: Date              // String 이 아니라 Date. APIDecoder 가 ISO8601 을 처리한다
}
```

- **envelope 래퍼를 만들지 않는다.** `RoomsResponseDTO { let data: [RoomDTO] }` 같은 타입은 필요 없다
- `Date` 로 선언한다. 문자열로 받아 직접 파싱하지 않는다
- **`internal` 로 닫는다.** `public` 이면 DTO 가 Domain 으로 샌다

### 3) 경계 매핑 — `toDomain()`

```swift
extension RoomDTO {
    func toDomain() -> Room {
        Room(id: id, name: name, description: description, createdAt: createdAt)
    }
}
```

### 4) Repository 구현 — `Data/Repositories/`

```swift
public final class RoomRepositoryImpl: RoomRepository {
    private let client: HTTPClient
    public init(client: HTTPClient) { self.client = client }

    public func rooms() async throws -> [Room] {
        do {
            return try await client.request(RoomAPI.list()).map { $0.toDomain() }
        } catch let error as NetworkError {
            throw Self.mapToDomain(error)
        }
    }

    /// 반부패 계층: 인프라 오류를 도메인 어휘로 번역한다.
    ///
    /// **케이스가 아니라 `statusCode` 로 분기한다.** 같은 404 가 본문 모양에 따라
    /// `.notFound` 로도 `.unexpectedErrorFormat(404, _)` 로도 오기 때문이다 —
    /// 프록시가 HTML 을 끼워 넣으면 후자다. 케이스만 보면 그 404 를 놓친다.
    private static func mapToDomain(_ error: NetworkError) -> Error {
        if case .cancelled = error { return CancellationError() }   // 취소는 실패가 아니다

        switch error.statusCode {
        case 401: return DomainError.unauthorized
        case 404: return DomainError.roomsFetchFailed
        default:
            // 번역하지 못했다는 사실은 반드시 남긴다 — 어떤 DomainError 를 추가해야
            // 하는지 알 수 있는 유일한 단서다. 이 로그가 없으면 403·409·타임아웃이
            // 전부 "알 수 없는 오류" 로 수렴하고 아무도 눈치채지 못한다.
            Log.warning("도메인으로 번역되지 않음", metadata: [
                "error": String(describing: error),
                "status": error.statusCode.map(String.init) ?? "-",
                "code": error.errorCode ?? "-",
            ])
            return DomainError.unknown
        }
    }
}
```

> `Log` 를 쓰려면 `Packages/Data/Package.swift` 에 `Logging` 의존을 추가한다.

**`DomainError` 케이스를 미리 만들지 않는다.** 403·409 를 화면이 구분해 보여줘야 할 때
그때 추가한다. 대신 **번역되지 않은 오류는 로그에 남겨** 무엇을 추가해야 하는지 드러낸다.

- `NetworkError` 를 그대로 던지지 않는다 — **Domain 이 인프라를 모르게** 한다
- `DomainError` 에 새 어휘가 필요한지는 **화면이 판단한다.** 403·409 를 화면이 구분해 보여줘야 하면 그때 `DomainError` 에 추가한다. 안 쓸 케이스를 미리 만들지 않는다

### 5) Domain 에 프로토콜·UseCase

```swift
// Domain/Repositories/RoomRepository.swift
public protocol RoomRepository: Sendable { func rooms() async throws -> [Room] }

// Domain/UseCases/FetchRoomsUseCase.swift
public protocol FetchRoomsUseCase: Sendable { func execute() async throws -> [Room] }
```

### 6) 조립 — `App/AppDependencies.swift`

```swift
// 초기화 경로는 baseURL 하나뿐이다 — 세션·타임아웃·재시도·로깅이 이미 앱 규칙대로 묶여 있다.
let client = URLSessionHTTPClient(baseURL: /* §최초 1회 배선 참조 */)
self.fetchRooms = DefaultFetchRoomsUseCase(repository: RoomRepositoryImpl(client: client))
```

클라이언트는 여러 개 만들어도 된다 — `Session` 은 프로세스에 하나이므로 연결 풀이 쪼개지거나
해제 중 요청이 오류로 뒤집히지 않는다. 그래도 조립은 컴포지션 루트에 모으는 게 낫다(의존 그래프가 한눈에 보인다).

### 7) 테스트

Repository 는 **`HTTPClient` 를 직접 스텁**한다. 실제 HTTP 를 태우지 않는다 — 검증 대상은 매핑과 에러 변환이다.

**JSON 을 주고 실제로 디코딩하게 한다** — 강제 캐스팅(`as! T`)이 필요 없고, DTO 필드명·날짜 형식까지 함께 검증된다.

```swift
private struct StubHTTPClient: HTTPClient {
    /// envelope 이 **아니라** 알맹이 JSON 을 준다(`[{...}]`). 클라이언트가 이미 벗긴 뒤의 모양이다.
    var json: Data = Data()
    var error: NetworkError?
    var pagination = Pagination(pageSize: 20, page: 0, hasNext: false)

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        if let error { throw error }
        return try APIDecoder.make().decode(T.self, from: json)   // T: Decodable
    }
    func requestPage<E>(_ endpoint: PagedEndpoint<E>) async throws -> Page<E> {
        if let error { throw error }
        return Page(items: try APIDecoder.make().decode([E].self, from: json), pagination: pagination)
    }
}

// 성공 경로 — envelope 없이 배열만 준다
let sut = RoomRepositoryImpl(client: StubHTTPClient(json: Data(#"[{"id":"room-1", ...}]"#.utf8)))
// 실패 경로
let sut = RoomRepositoryImpl(client: StubHTTPClient(error: .forbidden(code: "FORBIDDEN", message: "…")))
```

호출한 엔드포인트를 검증하려면 스텁이 `endpoint.path`·`endpoint.method` 를 기록해두고 확인한다.

`URLProtocolStub` 은 Networking 내부 전용이다(클라이언트 자체를 검증하는 도구). Data 테스트에서 쓰지 않는다.

---

## 페이지네이션

서버 공통 규약은 offset 기반이다 — `page`(0부터)·`pageSize`(기본 20, 최대 100) 쿼리, 응답에 `data` 의 **형제**로 `pagination { pageSize, page, hasNext }`.

```swift
// 페이지네이션 — paged() 가 PagedEndpoint 를 만들고, requestPage 만 그걸 받는다
let page = try await client.requestPage(PinAPI.list(roomId: id).paged(page: 0, pageSize: 20))
page.items                  // [PinDTO]
page.pagination.hasNext     // 옵셔널이 아니다

// 전체 조회 — page/pageSize 를 안 보내면 서버가 전부 준다(지도 전체 보기 등)
let all = try await client.request(PinAPI.list(roomId: id))   // [PinDTO]

// DTO → Entity 는 map 으로 페이지 정보를 유지한 채 옮긴다
let domain: Page<Pin> = page.map { $0.toDomain() }
```

- **짝이 타입으로 강제된다.** `paged()` 를 붙인 요청은 `request` 로 보낼 수 없고, 안 붙인 요청은 `requestPage` 로 보낼 수 없다 — `hasNext` 를 잃는 실수가 컴파일에서 막힌다
- 페이지 요청인데 서버가 `pagination` 을 빠뜨리면 **계약 위반으로 에러**를 낸다(조용히 nil 로 넘기지 않는다)

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
| `import Alamofire` (Networking 밖에서) | 라이브러리 격리가 깨지고 교체가 불가능해진다. **CI(`layer-guard`)가 막는다** |
| `JSONDecoder()` 직접 생성 | 날짜 전략이 갈린다. 디코딩은 클라이언트가 한다 |
| Entity 에 `Codable` 부착 | Domain 이 API 스키마와 결합된다 |
| DTO 를 `public` 으로 | Domain 으로 샌다 |
| envelope 래퍼 DTO | 클라이언트가 이미 벗긴다 |
| Repository 에서 `NetworkError` 를 그대로 던지기 | Domain 이 인프라를 알게 된다 |
| Repository 안에서 `Endpoint(...)` 직접 생성 | 경로가 흩어진다. 반드시 `Data/API/` 의 `enum` 을 거친다 |
| 오류를 **케이스로만** 분기 | 같은 404 가 `.notFound` 로도 `.unexpectedErrorFormat(404,_)` 로도 온다. `error.statusCode` 를 축으로 쓴다 |
| 번역 안 된 오류를 조용히 `.unknown` 으로 | 어떤 `DomainError` 를 추가해야 하는지 알 단서가 사라진다. `default` 에 로그를 남긴다 |

---

## 인증

**대부분의 API 는 토큰이 필요하다.** 스펙상 인증 예외는 `POST /api/v1/users` 와 `GET /api/v1/invitations/{code}` **둘뿐**이다.

```swift
Endpoint(path: "api/v1/users", method: .post, body: .json(dto), requiresAuth: false)
```

⚠️ **인증은 아직 구현되지 않았다.** 인증 설계 문서(로그인·토큰 갱신 엔드포인트)가 확정되면 붙인다. 그전까지 인증이 필요한 API 는 401 을 받는다.

---

## 최초 1회 배선

아직 아무도 `AppDependencies` 에서 실제 클라이언트를 만들지 않았다. 첫 실 API 연동자가 함께 한다.

- `APIEnvironment`(local `http://localhost:3000` / production `https://api.gguk.org`) 와 baseURL 공급 경로(xcconfig → Info.plist)
- **ATS 예외** — local 이 `http` 라 `NSAllowsLocalNetworking` 이 없으면 로컬 서버에 못 붙는다. **Debug 전용**으로 두고 Release 로 새지 않게 한다

---

## 아직 없는 것

| | 상태 |
|---|---|
| 인증(토큰 주입·갱신) | 인증 설계 문서 대기 |
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
