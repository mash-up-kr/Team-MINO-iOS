import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 링크 저장의 계약을 고정한다. 핵심은 **방마다 요청이 따로 나간다**는 점과,
/// 하나가 실패해도 나머지 방에는 요청이 나가야 한다는 점이다.
@Suite("SaveLinkRepositoryImpl")
struct SaveLinkRepositoryImplTests {
    private static let link = URL(string: "https://www.instagram.com/p/abc123/")!

    @Test("방마다 POST api/v1/rooms/{id}/pins 가 나가고 본문에 링크가 실린다")
    func save_sendsOneRequestPerRoom() async throws {
        let client = MultiRequestStub()
        let sut = SaveLinkRepositoryImpl(client: client)

        try await sut.save(url: Self.link, toRoomIDs: ["room-1", "room-2", "room-3"])

        #expect(await client.paths == [
            "api/v1/rooms/room-1/pins",
            "api/v1/rooms/room-2/pins",
            "api/v1/rooms/room-3/pins",
        ])
        #expect(await client.methods == [.post])
        #expect(await client.sentURLs == [Self.link.absoluteString])
    }

    // 첫 실패에서 빠져나오면 남은 방은 요청조차 못 나간다 — 보낼 수 있는 건 다 보내고 판단한다.
    @Test("한 방이 실패해도 나머지 방에는 요청이 나간다")
    func save_keepsGoingAfterFailure() async {
        let client = MultiRequestStub(failing: ["room-2"], error: NetworkError.server(statusCode: 500))
        let sut = SaveLinkRepositoryImpl(client: client)

        try? await sut.save(url: Self.link, toRoomIDs: ["room-1", "room-2", "room-3"])

        #expect(await client.paths.count == 3)
    }

    @Test("하나라도 실패하면 저장 실패로 던진다")
    func save_throwsWhenAnyRoomFails() async {
        let client = MultiRequestStub(failing: ["room-2"], error: NetworkError.server(statusCode: 500))
        let sut = SaveLinkRepositoryImpl(client: client)

        await #expect(throws: DomainError.linkSaveFailed) {
            try await sut.save(url: Self.link, toRoomIDs: ["room-1", "room-2"])
        }
    }

    // 이미 그 방에 있는 링크(400 DUPLICATE_PIN_IN_ROOM)도 실패로 흡수한다 —
    // 화면이 "일부만 성공"을 표현하지 않기로 했으므로 구분해도 보여줄 자리가 없다.
    @Test("중복 저장(400)도 저장 실패로 수렴한다")
    func save_duplicateBecomesFailure() async {
        let client = MultiRequestStub(
            failing: ["room-1"],
            error: NetworkError.badRequest(code: "DUPLICATE_PIN_IN_ROOM", message: "이미 있음")
        )
        let sut = SaveLinkRepositoryImpl(client: client)

        await #expect(throws: DomainError.linkSaveFailed) {
            try await sut.save(url: Self.link, toRoomIDs: ["room-1"])
        }
    }

    @Test("401 은 재인증이 필요한 unauthorized 로 번역된다")
    func unauthorizedIsTranslated() async {
        let client = MultiRequestStub(
            failing: ["room-1"],
            error: NetworkError.unauthorized(code: "TOKEN_EXPIRED", message: "만료")
        )
        let sut = SaveLinkRepositoryImpl(client: client)

        await #expect(throws: DomainError.unauthorized) {
            try await sut.save(url: Self.link, toRoomIDs: ["room-1"])
        }
    }

    // 취소는 실패가 아니다 — 섞여 있으면 취소를 우선 던져 화면이 오류 UI 를 띄우지 않게 한다.
    @Test("취소가 섞이면 CancellationError 가 우선한다")
    func cancellationWinsOverFailure() async {
        let client = MultiRequestStub(
            errorsByRoom: [
                "room-1": NetworkError.server(statusCode: 500),
                "room-2": NetworkError.cancelled,
            ]
        )
        let sut = SaveLinkRepositoryImpl(client: client)

        await #expect(throws: CancellationError.self) {
            try await sut.save(url: Self.link, toRoomIDs: ["room-1", "room-2"])
        }
    }

    @Test("고른 방이 없으면 요청이 나가지 않는다")
    func save_withNoRooms_sendsNothing() async throws {
        let client = MultiRequestStub()
        let sut = SaveLinkRepositoryImpl(client: client)

        try await sut.save(url: Self.link, toRoomIDs: [])

        #expect(await client.paths.isEmpty)
    }
}

/// 요청을 **전부** 기록하는 스텁. 방마다 요청이 나가므로 마지막 하나만 봐서는 검증이 안 된다.
/// 병렬로 나가 순서가 뒤섞이므로 `paths` 는 정렬해 돌려준다.
private actor MultiRequestStub: HTTPClient {
    private let errorsByRoom: [String: Error]
    private var recordedPaths: [String] = []
    private var recordedMethods: Set<HTTPMethod> = []
    private var recordedURLs: Set<String> = []

    init(failing roomIDs: Set<String> = [], error: Error = NetworkError.server(statusCode: 500)) {
        self.errorsByRoom = Dictionary(uniqueKeysWithValues: roomIDs.map { ($0, error) })
    }

    init(errorsByRoom: [String: Error]) {
        self.errorsByRoom = errorsByRoom
    }

    var paths: [String] { recordedPaths.sorted() }
    var methods: Set<HTTPMethod> { recordedMethods }
    var sentURLs: Set<String> { recordedURLs }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        recordedPaths.append(endpoint.path)
        recordedMethods.insert(endpoint.method)
        if let url = try Self.encodedBody(endpoint.body)?["url"] as? String {
            recordedURLs.insert(url)
        }

        if let (_, error) = errorsByRoom.first(where: { endpoint.path.contains("/\($0.key)/") }) {
            throw error
        }
        // 202 는 본문이 없다 — 클라이언트가 빈 본문을 OkResponse 로 통과시키는 자리를 흉내낸다.
        return try APIDecoder.make().decode(T.self, from: Data(#"{"ok":true}"#.utf8))
    }

    // Domain 에도 Page 가 생겨(목록 API 공용 값 타입) 두 모듈을 함께 import 하는 이 파일에서는 모호하다.
    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Networking.Page<Element> {
        throw NetworkError.cancelled   // 핀 저장은 페이지네이션을 쓰지 않는다
    }

    private static func encodedBody(_ body: HTTPBody?) throws -> [String: Any]? {
        guard case .json(let encodable) = body else { return nil }
        let data = try APIEncoder.make().encode(encodable)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
