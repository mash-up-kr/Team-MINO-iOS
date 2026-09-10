import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 방 나가기·방장 위임의 계약을 고정한다 — 경로·메서드·본문, 그리고 409 가 "실패" 가 아니라
/// **위임 요구**로 번역되는지.
@Suite("RoomMembershipRepositoryImpl")
struct RoomMembershipRepositoryImplTests {
    private static let roomID = "room-1"
    private static let okJSON = #"{ "ok": true }"#

    // MARK: 나가기

    // 방을 지우는 게 아니라 내 멤버십을 지운다 — 경로가 `members/me` 인 것이 그 뜻이다.
    @Test("나가기는 DELETE api/v1/rooms/{id}/members/me 로 나간다")
    func leave_sendsDeleteToMembersMe() async throws {
        let client = StubMembershipClient(json: Self.okJSON)
        let sut = RoomMembershipRepositoryImpl(client: client)

        try await sut.leave(roomId: Self.roomID)

        #expect(await client.lastPath == "api/v1/rooms/room-1/members/me")
        #expect(await client.lastMethod == .delete)
    }

    // 409 는 실패가 아니라 다음 절차의 요구다 — 화면이 이 값 하나로 새 방장 고르기를 띄운다.
    @Test("409 OWNER_TRANSFER_REQUIRED 는 위임 요구로 번역된다")
    func leave_conflictBecomesOwnerTransferRequired() async {
        let client = StubMembershipClient(
            error: NetworkError.conflict(code: "OWNER_TRANSFER_REQUIRED", message: "위임이 필요합니다.")
        )
        let sut = RoomMembershipRepositoryImpl(client: client)

        await #expect(throws: DomainError.ownerTransferRequired) {
            try await sut.leave(roomId: Self.roomID)
        }
    }

    // 같은 409 라도 코드가 다르면 위임 화면을 띄우면 안 된다 — 넘길 사람을 고를 상황이 아니다.
    @Test("다른 코드의 409 는 위임 요구가 아니라 나가기 실패다")
    func leave_otherConflictIsPlainFailure() async {
        let client = StubMembershipClient(
            error: NetworkError.conflict(code: "SOMETHING_ELSE", message: "…")
        )
        let sut = RoomMembershipRepositoryImpl(client: client)

        await #expect(throws: DomainError.roomLeaveFailed) {
            try await sut.leave(roomId: Self.roomID)
        }
    }

    @Test("401 은 재인증이 필요한 unauthorized 로 번역된다")
    func leave_unauthorized() async {
        let client = StubMembershipClient(
            error: NetworkError.unauthorized(code: "TOKEN_EXPIRED", message: "만료")
        )
        let sut = RoomMembershipRepositoryImpl(client: client)

        await #expect(throws: DomainError.unauthorized) {
            try await sut.leave(roomId: Self.roomID)
        }
    }

    @Test("취소는 실패가 아니라 CancellationError 로 되돌린다")
    func leave_cancelled() async {
        let client = StubMembershipClient(error: NetworkError.cancelled)
        let sut = RoomMembershipRepositoryImpl(client: client)

        await #expect(throws: CancellationError.self) {
            try await sut.leave(roomId: Self.roomID)
        }
    }

    // MARK: 방장 위임

    // POST·PATCH 가 아니라 PUT 이다(스펙 실측). 틀리면 404 로 조용히 실패한다.
    @Test("위임은 PUT api/v1/rooms/{id}/owner 로 nextOwnerId 를 보낸다")
    func transferOwner_sendsPut() async throws {
        let client = StubMembershipClient(json: Self.okJSON)
        let sut = RoomMembershipRepositoryImpl(client: client)

        try await sut.transferOwner(roomId: Self.roomID, nextOwnerId: "u2")

        #expect(await client.lastPath == "api/v1/rooms/room-1/owner")
        #expect(await client.lastMethod == .put)
        #expect(await client.lastBodyValue("nextOwnerId") == "u2")
    }

    @Test("403(방장 아님)·400(대상이 멤버 아님)은 위임 실패로 모인다")
    func transferOwner_clientErrorsBecomeTransferFailed() async {
        for error: NetworkError in [
            .forbidden(code: "NOT_ROOM_OWNER", message: "…"),
            .client(statusCode: 400, code: "VALIDATION_ERROR", message: "…"),
        ] {
            let sut = RoomMembershipRepositoryImpl(client: StubMembershipClient(error: error))

            await #expect(throws: DomainError.ownerTransferFailed) {
                try await sut.transferOwner(roomId: Self.roomID, nextOwnerId: "u2")
            }
        }
    }
}

private actor StubMembershipClient: HTTPClient {
    private let json: String?
    private let error: Error?
    private(set) var lastPath: String?
    private(set) var lastMethod: HTTPMethod?
    private(set) var lastBody: [String: Any]?

    init(json: String? = nil, error: Error? = nil) {
        self.json = json
        self.error = error
    }

    /// 요청 본문의 문자열 값. 키 자체가 없으면 nil.
    func lastBodyValue(_ key: String) -> String? {
        lastBody?[key] as? String
    }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        lastPath = endpoint.path
        lastMethod = endpoint.method
        lastBody = try Self.encodedBody(endpoint.body)

        if let error { throw error }
        guard let json else { throw NetworkError.cancelled }
        return try APIDecoder.make().decode(T.self, from: Data(json.utf8))
    }

    // Domain 에도 같은 이름의 `Page` 가 있어 모듈로 한정한다.
    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Networking.Page<Element> {
        throw NetworkError.cancelled   // 나가기·위임은 페이지네이션을 쓰지 않는다
    }

    /// 실제 인코더를 태워 "서버에 나가는 모양" 그대로 본다.
    private static func encodedBody(_ body: HTTPBody?) throws -> [String: Any]? {
        guard case .json(let encodable) = body else { return nil }
        let data = try APIEncoder.make().encode(encodable)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
