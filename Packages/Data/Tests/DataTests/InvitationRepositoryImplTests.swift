import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 검증 대상은 **매핑과 에러 변환**이다 — 실제 HTTP 는 태우지 않는다(AddingAPI.md §7).
struct InvitationRepositoryImplTests {
    @Test("방 아래 초대 경로로 POST 하고 코드만 꺼내 온다")
    func inviteCode_hitsRoomInvitationEndpoint() async throws {
        let client = StubHTTPClient(result: .success(InviteCodeDTO(code: "K7Q2MZ")))

        let code = try await InvitationRepositoryImpl(client: client).inviteCode(roomId: "room-1")

        #expect(code == "K7Q2MZ")
        #expect(await client.lastPath == "api/v1/rooms/room-1/invitations")
        #expect(await client.lastMethod == .post)
    }

    @Test("401 은 unauthorized 로 번역한다 — 세션이 끊긴 것과 초대 실패는 다르다")
    func unauthorized_mapsToDomain() async {
        let client = StubHTTPClient(result: .failure(NetworkError.unauthorized(code: nil, message: nil)))
        await #expect(throws: DomainError.unauthorized) {
            try await InvitationRepositoryImpl(client: client).inviteCode(roomId: "room-1")
        }
    }

    // 403(방 멤버 아님·개인방)·404(방 없음) 는 사용자가 이 화면에서 할 수 있는 일이 같아 하나로 모은다.
    @Test("403 은 초대 실패로 모은다")
    func forbidden_mapsToInviteFailure() async {
        let client = StubHTTPClient(result: .failure(NetworkError.forbidden(code: "PERSONAL_ROOM_NOT_ALLOWED", message: "개인방은 초대할 수 없습니다.")))
        await #expect(throws: DomainError.inviteCodeFetchFailed) {
            try await InvitationRepositoryImpl(client: client).inviteCode(roomId: "room-1")
        }
    }

    @Test("번역되지 않은 상태코드도 초대 실패로 떨어진다")
    func unmappedStatus_fallsBack() async {
        let client = StubHTTPClient(result: .failure(NetworkError.conflict(code: "SOMETHING", message: "알 수 없는 충돌")))
        await #expect(throws: DomainError.inviteCodeFetchFailed) {
            try await InvitationRepositoryImpl(client: client).inviteCode(roomId: "room-1")
        }
    }

    @Test("취소는 실패가 아니다 — CancellationError 로 되돌린다")
    func cancellation_isNotFailure() async {
        let client = StubHTTPClient(result: .failure(NetworkError.cancelled))
        await #expect(throws: CancellationError.self) {
            try await InvitationRepositoryImpl(client: client).inviteCode(roomId: "room-1")
        }
    }
}

// MARK: - 초대 수락 (미리보기 · 합류)

/// 발급과 달리 **403·404 를 갈라** 도메인 어휘로 준다 — 사용자에게 보여줄 문구가 다르기 때문이다.
struct InvitationAcceptanceTests {
    @Test("미리보기는 인증 없이 초대 경로를 치고, 방과 초대자를 도메인으로 옮긴다")
    func preview_mapsToDomain() async throws {
        let client = StubHTTPClient(result: .success(Fixture.preview))

        let preview = try await InvitationRepositoryImpl(client: client).invitationPreview(code: "AB12CD")

        #expect(preview.roomID == "room-1")
        #expect(preview.roomName == "5월의 약속")
        #expect(preview.roomColor == .pink)
        #expect(preview.pinCount == 12)
        #expect(preview.inviterNickname == "지은")
        #expect(await client.lastPath == "api/v1/invitations/AB12CD")
        #expect(await client.lastMethod == .get)
        // 온보딩 전에도 부를 수 있어야 한다 — 세션이 없는 사용자가 초대 유효성을 먼저 확인한다.
        #expect(await client.lastAuthWasNone)
    }

    /// 팔레트에 없는 색은 `nil` 로 떨어뜨린다(`RoomDTO.toDomain()` 과 같은 규약).
    @Test("모르는 색·모르는 방 유형은 보수적으로 접는다")
    func preview_unknownEnumsFallBack() async throws {
        let client = StubHTTPClient(result: .success(Fixture.preview(color: "무지개", type: "galaxy")))

        let preview = try await InvitationRepositoryImpl(client: client).invitationPreview(code: "AB12CD")

        #expect(preview.roomColor == nil)
        #expect(preview.roomType == .shared)
    }

    @Test("404 는 만료된 초대다 — 발급 실패와 갈라야 문구가 달라진다")
    func preview_notFound_mapsToInvitationNotFound() async {
        let client = StubHTTPClient(result: .failure(NetworkError.notFound(code: "INVITATION_NOT_FOUND", message: "초대를 찾을 수 없습니다.")))
        await #expect(throws: DomainError.invitationNotFound) {
            try await InvitationRepositoryImpl(client: client).invitationPreview(code: "AB12CD")
        }
    }

    @Test("403 은 개인방이다")
    func preview_forbidden_mapsToPersonalRoom() async {
        let client = StubHTTPClient(result: .failure(NetworkError.forbidden(code: "PERSONAL_ROOM_NOT_ALLOWED", message: "개인방입니다.")))
        await #expect(throws: DomainError.personalRoomNotAllowed) {
            try await InvitationRepositoryImpl(client: client).invitationPreview(code: "AB12CD")
        }
    }

    /// 초대가 무효한 것과 네트워크에 닿지 못한 것을 가른다 — 후자는 다시 눌러 볼 수 있다.
    @Test("네트워크에 닿지 못하면 networkUnavailable 이다")
    func preview_transportFailure_mapsToNetworkUnavailable() async {
        let client = StubHTTPClient(result: .failure(NetworkError.transport(reason: .notConnected)))
        await #expect(throws: DomainError.networkUnavailable) {
            try await InvitationRepositoryImpl(client: client).invitationPreview(code: "AB12CD")
        }
    }

    /// `.unknown` 은 TLS 실패까지 섞여 있어 연결 문제라고 단정하지 않는다.
    @Test("갈래를 모르는 전송 실패는 unknown 으로 흡수한다")
    func preview_unknownTransport_mapsToUnknown() async {
        let client = StubHTTPClient(result: .failure(NetworkError.transport(reason: .unknown)))
        await #expect(throws: DomainError.unknown) {
            try await InvitationRepositoryImpl(client: client).invitationPreview(code: "AB12CD")
        }
    }

    @Test("합류는 방 멤버 경로로 POST 하고 본문에 초대 코드를 싣는다")
    func join_hitsMembersEndpointWithCode() async throws {
        let client = StubHTTPClient(result: .success(JoinRoomResponseDTO(ok: true)))

        try await InvitationRepositoryImpl(client: client).joinRoom(roomId: "room-1", inviteCode: "AB12CD")

        #expect(await client.lastPath == "api/v1/rooms/room-1/members")
        #expect(await client.lastMethod == .post)
        let body = try #require(await client.lastBodyData)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(json?["inviteCode"] as? String == "AB12CD")
    }

    /// 서버가 미등록을 401 로 막는다 — 합류를 유저 등록 앞에 두면 여기 걸린다.
    @Test("미등록 401 은 notRegistered 로 번역한다")
    func join_userNotRegistered_mapsToNotRegistered() async {
        let client = StubHTTPClient(result: .failure(NetworkError.unauthorized(code: NetworkError.userNotRegisteredCode, message: nil)))
        await #expect(throws: DomainError.notRegistered) {
            try await InvitationRepositoryImpl(client: client).joinRoom(roomId: "room-1", inviteCode: "AB12CD")
        }
    }

    @Test("합류 중 초대가 사라지면 만료로 떨어진다 — 온보딩을 도는 사이에 생길 수 있다")
    func join_notFound_mapsToInvitationNotFound() async {
        let client = StubHTTPClient(result: .failure(NetworkError.notFound(code: "INVITATION_NOT_FOUND", message: "초대를 찾을 수 없습니다.")))
        await #expect(throws: DomainError.invitationNotFound) {
            try await InvitationRepositoryImpl(client: client).joinRoom(roomId: "room-1", inviteCode: "AB12CD")
        }
    }

    @Test("취소는 실패가 아니다")
    func join_cancellation_isNotFailure() async {
        let client = StubHTTPClient(result: .failure(NetworkError.cancelled))
        await #expect(throws: CancellationError.self) {
            try await InvitationRepositoryImpl(client: client).joinRoom(roomId: "room-1", inviteCode: "AB12CD")
        }
    }
}

private enum Fixture {
    static var preview: InvitationPreviewDTO { preview() }

    static func preview(color: String = "pink", type: String = "shared") -> InvitationPreviewDTO {
        InvitationPreviewDTO(
            room: .init(
                id: "room-1",
                type: type,
                name: "5월의 약속",
                description: "우리 모임 장소 픽업 공간.",
                color: color,
                pinCount: 12,
                memberCount: 4
            ),
            inviter: .init(nickname: "지은")
        )
    }
}

/// 요청을 기록하고 정해진 결과를 돌려주는 `HTTPClient`.
///
/// 응답 타입이 엔드포인트마다 달라 `any Sendable` 로 받는다 — 캐스팅이 어긋나면 테스트가
/// 조용히 통과하지 않도록 실패로 떨어뜨린다.
private actor StubHTTPClient: HTTPClient {
    private let result: Result<any Sendable, Error>
    private(set) var lastPath: String?
    private(set) var lastMethod: HTTPMethod?
    /// 인코딩된 본문 원문. `[String: Any]` 는 Sendable 이 아니라 actor 밖으로 못 나간다.
    private(set) var lastBodyData: Data?
    /// `AuthRequirement` 는 Equatable 이 아니라 패턴으로 본다.
    private(set) var lastAuthWasNone = false

    init(result: Result<any Sendable, Error>) {
        self.result = result
    }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        lastPath = endpoint.path
        lastMethod = endpoint.method
        if case .none = endpoint.auth { lastAuthWasNone = true }
        lastBodyData = Self.encoded(endpoint.body)

        switch result {
        case .success(let value):
            guard let typed = value as? T else {
                throw StubMismatch(expected: "\(T.self)", got: "\(Swift.type(of: value))")
            }
            return typed
        case .failure(let error):
            throw error
        }
    }

    // Domain 에도 Page 가 생겨(목록 API 공용 값 타입) 두 모듈을 함께 import 하는 이 파일에서는 모호하다.
    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Networking.Page<Element> {
        throw NetworkError.cancelled   // 초대는 페이지네이션을 쓰지 않는다
    }

    private static func encoded(_ body: HTTPBody?) -> Data? {
        guard case .json(let encodable) = body else { return nil }
        return try? JSONEncoder().encode(encodable)
    }
}

private struct StubMismatch: Error {
    let expected: String
    let got: String
}
