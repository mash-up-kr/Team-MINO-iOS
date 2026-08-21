# Adding a New API

화면에 API 를 붙이는 절차. 패키지 개요·금지 항목·동작 기본값은 [`../README.md`](../README.md) 를 본다.

`GET /api/v1/rooms`(내가 속한 방 목록)를 예로 든다.

## 1) 엔드포인트 정의 — `Data/API/`

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

## 2) DTO 작성 — `Data/DTO/`

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

## 3) 경계 매핑 — `toDomain()`

```swift
extension RoomDTO {
    func toDomain() -> Room {
        Room(id: id, name: name, description: description, createdAt: createdAt)
    }
}
```

## 4) Repository 구현 — `Data/Repositories/`

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
            //
            // 오류는 `label`(케이스 이름)로만 남긴다. `String(describing:)` 으로 통째로
            // 찍으면 연관값의 서버 원문 message·에러 본문 preview 가 릴리즈 기기 로그에
            // 평문으로 남는다(README §금지).
            Log.warning("도메인으로 번역되지 않음", metadata: [
                "error": error.label,
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

## 5) Domain 에 프로토콜·UseCase

```swift
// Domain/Repositories/RoomRepository.swift
public protocol RoomRepository: Sendable { func rooms() async throws -> [Room] }

// Domain/UseCases/FetchRoomsUseCase.swift
public protocol FetchRoomsUseCase: Sendable { func execute() async throws -> [Room] }
```

## 6) 조립 — `App/AppDependencies.swift`

```swift
// 초기화 경로는 baseURL 하나뿐이다 — 세션·타임아웃·재시도·로깅이 이미 앱 규칙대로 묶여 있다.
let client = URLSessionHTTPClient(baseURL: /* §최초 1회 배선 참조 */)
self.fetchRooms = DefaultFetchRoomsUseCase(repository: RoomRepositoryImpl(client: client))
```

클라이언트는 여러 개 만들어도 된다 — `Session` 은 프로세스에 하나이므로 연결 풀이 쪼개지거나
해제 중 요청이 오류로 뒤집히지 않는다. 그래도 조립은 컴포지션 루트에 모으는 게 낫다(의존 그래프가 한눈에 보인다).

## 7) 테스트

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

// DTO → Entity 매핑은 Repository **안에서** 한다
let entities = page.map { $0.toDomain() }.items
```

- **짝이 타입으로 강제된다.** `paged()` 를 붙인 요청은 `request` 로 보낼 수 없고, 안 붙인 요청은 `requestPage` 로 보낼 수 없다 — `hasNext` 를 잃는 실수가 컴파일에서 막힌다
- 페이지 요청인데 서버가 `pagination` 을 빠뜨리면 **계약 위반으로 에러**를 낸다(조용히 nil 로 넘기지 않는다)

### ⚠️ `Page` 를 Domain 경계 밖으로 내보내지 않는다

`Page` 는 **Networking 타입**이다. Repository 가 `Page<Pin>` 을 반환하면 Domain 의 프로토콜이
그 타입을 알아야 하고, 그러면 **Domain 이 Networking 을 의존**하게 된다 —
`Domain 은 의존 0` 규칙 위반이라 CI(`layer-guard`)가 막는다.

```swift
// ❌ Domain 이 Networking 을 알아야 한다
public protocol PinRepository {
    func pins(page: Int) async throws -> Page<Pin>
}

// ⭕ 페이지 정보가 필요하면 Domain 자기 타입으로 표현한다
public struct PinPage: Sendable {          // Domain
    public let pins: [Pin]
    public let hasNext: Bool
}
public protocol PinRepository {
    func pins(page: Int) async throws -> PinPage
}
```

`Page.map` 은 **Data 안에서** DTO → Entity 로 옮길 때 쓰고, 경계에서는 Domain 타입으로 바꾼다.

```swift
// Data/Repositories/PinRepositoryImpl.swift
let page = try await client.requestPage(PinAPI.list(roomId: id).paged(page: page, pageSize: 20))
return PinPage(pins: page.items.map { $0.toDomain() }, hasNext: page.pagination.hasNext)
```
