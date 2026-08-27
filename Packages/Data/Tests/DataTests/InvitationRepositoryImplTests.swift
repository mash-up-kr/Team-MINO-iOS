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

/// 요청을 기록하고 정해진 결과를 돌려주는 `HTTPClient`.
private actor StubHTTPClient: HTTPClient {
    private let result: Result<InviteCodeDTO, Error>
    private(set) var lastPath: String?
    private(set) var lastMethod: HTTPMethod?

    init(result: Result<InviteCodeDTO, Error>) {
        self.result = result
    }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        lastPath = endpoint.path
        lastMethod = endpoint.method
        switch result {
        case .success(let dto):
            guard let typed = dto as? T else {
                throw NetworkError.cancelled   // 이 테스트에서 나올 일이 없는 경로
            }
            return typed
        case .failure(let error):
            throw error
        }
    }

    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Page<Element> {
        throw NetworkError.cancelled   // 초대는 페이지네이션을 쓰지 않는다
    }
}
