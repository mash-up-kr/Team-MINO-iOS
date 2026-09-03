import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 「다른 방에 공유」 저장의 계약을 고정한다 — 어떤 경로·메서드로 나가고, 고른 방들이 한 요청에
/// 실리며, 인프라 오류가 어떤 도메인 어휘가 되는지.
@Suite("SavePinRepositoryImpl")
struct SavePinRepositoryImplTests {
    private static let pinID = PinID("pin-1")

    @Test("POST api/v1/pins/{pinId}/duplicate 한 번으로 고른 방들을 함께 보낸다")
    func save_sendsSingleRequestWithAllRooms() async throws {
        let client = StubHTTPClient()
        let sut = SavePinRepositoryImpl(client: client)

        try await sut.save(pinID: Self.pinID, toRoomIDs: ["room-1", "room-2", "room-3"])

        #expect(await client.callCount == 1)
        #expect(await client.lastPath == "api/v1/pins/pin-1/duplicate")
        #expect(await client.lastMethod == .post)
        #expect(await client.lastRoomIDs == ["room-1", "room-2", "room-3"])
    }

    @Test("방이 하나여도 배열로 실린다")
    func save_singleRoomStillArray() async throws {
        let client = StubHTTPClient()
        let sut = SavePinRepositoryImpl(client: client)

        try await sut.save(pinID: Self.pinID, toRoomIDs: ["room-1"])

        #expect(await client.lastRoomIDs == ["room-1"])
    }

    @Test("401 은 재인증이 필요한 unauthorized 로 번역된다")
    func unauthorizedIsTranslated() async {
        let client = StubHTTPClient(error: NetworkError.unauthorized(code: "TOKEN_EXPIRED", message: "만료"))
        let sut = SavePinRepositoryImpl(client: client)

        await #expect(throws: DomainError.unauthorized) {
            try await sut.save(pinID: Self.pinID, toRoomIDs: ["room-1"])
        }
    }

    // 서버가 **전체를 거절**한다(부분 성공 없음). 화면이 이미 담긴 방을 빼 두므로 정상 경로에서는
    // 나지 않지만, 그 목록이 낡았으면(다른 기기가 먼저 담음) 여기로 온다.
    @Test("중복 저장(409 DUPLICATE_PIN_IN_ROOM)은 공유 실패로 수렴한다")
    func duplicateBecomesFailure() async {
        let client = StubHTTPClient(
            error: NetworkError.server(statusCode: 409)
        )
        let sut = SavePinRepositoryImpl(client: client)

        await #expect(throws: DomainError.pinShareFailed) {
            try await sut.save(pinID: Self.pinID, toRoomIDs: ["room-1", "room-2"])
        }
    }

    @Test("번역되지 않은 상태코드도 공유 실패로 떨어진다 — 오류를 흘리지 않는다")
    func untranslatedStatusFallsBack() async {
        let client = StubHTTPClient(error: NetworkError.server(statusCode: 500))
        let sut = SavePinRepositoryImpl(client: client)

        await #expect(throws: DomainError.pinShareFailed) {
            try await sut.save(pinID: Self.pinID, toRoomIDs: ["room-1"])
        }
    }

    // 취소는 실패가 아니다 — 화면이 오류 UI 를 띄우지 않도록 CancellationError 로 돌려준다.
    @Test("취소는 CancellationError 로 되돌아온다")
    func cancellationStaysCancellation() async {
        let client = StubHTTPClient(error: NetworkError.cancelled)
        let sut = SavePinRepositoryImpl(client: client)

        await #expect(throws: CancellationError.self) {
            try await sut.save(pinID: Self.pinID, toRoomIDs: ["room-1"])
        }
    }
}

/// 요청을 기록하고 정해진 응답을 돌려주는 `HTTPClient` 스텁.
private actor StubHTTPClient: HTTPClient {
    private let error: Error?
    private(set) var callCount = 0
    private(set) var lastPath: String?
    private(set) var lastMethod: HTTPMethod?
    private var lastBody: [String: Any]?

    init(error: Error? = nil) {
        self.error = error
    }

    /// 순서를 고정해 비교한다 — `Set` 을 배열로 옮기므로 나가는 순서는 정해져 있지 않다.
    var lastRoomIDs: [String]? { (lastBody?["roomIds"] as? [String])?.sorted() }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        callCount += 1
        lastPath = endpoint.path
        lastMethod = endpoint.method
        lastBody = try Self.encodedBody(endpoint.body)

        if let error { throw error }
        return try APIDecoder.make().decode(T.self, from: Data(#"{"ok":true}"#.utf8))
    }

    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Networking.Page<Element> {
        throw NetworkError.cancelled   // 핀 공유는 페이지네이션을 쓰지 않는다
    }

    /// 실제 인코더를 태워 "서버에 나가는 모양" 그대로 본다.
    private static func encodedBody(_ body: HTTPBody?) throws -> [String: Any]? {
        guard case .json(let encodable) = body else { return nil }
        let data = try APIEncoder.make().encode(encodable)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
