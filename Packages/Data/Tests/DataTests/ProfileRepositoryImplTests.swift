import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 검증 대상은 **매핑과 에러 변환**이다 — 실제 HTTP 는 태우지 않는다(AddingAPI.md §7).
struct ProfileRepositoryImplTests {
    @Test("등록은 닉네임·아바타를 실어 보내고 응답을 Profile 로 옮긴다")
    func register_mapsResponse() async throws {
        let client = StubHTTPClient(result: .success(Self.dto(nickname: "민호", avatarID: 7)))
        let sut = ProfileRepositoryImpl(client: client)

        let profile = try await sut.register(nickname: "민호", avatarIndex: 7)

        #expect(profile.nickname == "민호")
        #expect(profile.avatarIndex == 7)
        #expect(await client.lastPath == "api/v1/users")
        #expect(await client.lastMethod == .post)
    }

    @Test("등록은 인증 미들웨어를 부분만 태운다 — full 이면 최초 진입이 막힌다")
    func register_usesUnregisteredUserAuth() async throws {
        let client = StubHTTPClient(result: .success(Self.dto()))
        _ = try await ProfileRepositoryImpl(client: client).register(nickname: "민호", avatarIndex: 0)

        guard case .unregisteredUser = await client.lastAuth else {
            Issue.record("register 는 .unregisteredUser 여야 한다")
            return
        }
    }

    @Test("조회는 GET /me 를 친다")
    func me_hitsMeEndpoint() async throws {
        let client = StubHTTPClient(result: .success(Self.dto(nickname: "꾹이", avatarID: 2)))
        let profile = try await ProfileRepositoryImpl(client: client).me()

        #expect(profile.avatarIndex == 2)
        #expect(await client.lastPath == "api/v1/users/me")
        #expect(await client.lastMethod == .get)
    }

    @Test("수정은 PATCH 로 보낸다")
    func update_usesPatch() async throws {
        let client = StubHTTPClient(result: .success(Self.dto()))
        _ = try await ProfileRepositoryImpl(client: client).update(nickname: "민호", avatarIndex: nil)

        #expect(await client.lastPath == "api/v1/users/me")
        #expect(await client.lastMethod == .patch)
    }

    @Test("아바타가 없는 계정도 읽을 수 있다 — 스펙상 nullable")
    func me_withoutAvatar() async throws {
        let client = StubHTTPClient(result: .success(Self.dto(avatarID: nil)))
        let profile = try await ProfileRepositoryImpl(client: client).me()

        #expect(profile.avatarIndex == nil)
    }

    @Test("401 은 unauthorized 로 번역한다 — 세션이 끊긴 것과 저장 실패는 다르다")
    func unauthorized_mapsToDomain() async {
        let client = StubHTTPClient(result: .failure(NetworkError.unauthorized(code: nil, message: nil)))
        await #expect(throws: DomainError.unauthorized) {
            try await ProfileRepositoryImpl(client: client).me()
        }
    }

    @Test("번역되지 않은 상태코드는 호출별 기본 오류로 떨어진다")
    func unmappedStatus_fallsBack() async {
        let client = StubHTTPClient(result: .failure(NetworkError.conflict(code: "ALREADY_EXISTS", message: "이미 등록된 사용자")))
        await #expect(throws: DomainError.profileSaveFailed) {
            try await ProfileRepositoryImpl(client: client).register(nickname: "민호", avatarIndex: 0)
        }
    }

    @Test("취소는 실패가 아니다 — CancellationError 로 되돌린다")
    func cancellation_isNotFailure() async {
        let client = StubHTTPClient(result: .failure(NetworkError.cancelled))
        await #expect(throws: CancellationError.self) {
            try await ProfileRepositoryImpl(client: client).me()
        }
    }

    private static func dto(nickname: String = "꾹이", avatarID: Int? = 0) -> ProfileDTO {
        ProfileDTO(
            id: "user-1",
            nickname: nickname,
            avatar: avatarID.map(AvatarDTO.init(id:)),
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}

/// 요청을 기록하고 정해진 결과를 돌려주는 `HTTPClient`.
private actor StubHTTPClient: HTTPClient {
    private let result: Result<ProfileDTO, Error>
    private(set) var lastPath: String?
    private(set) var lastMethod: HTTPMethod?
    private(set) var lastAuth: AuthRequirement?

    init(result: Result<ProfileDTO, Error>) {
        self.result = result
    }

    func request<T>(_ endpoint: Endpoint<T>) async throws -> T {
        lastPath = endpoint.path
        lastMethod = endpoint.method
        lastAuth = endpoint.auth
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
        throw NetworkError.cancelled   // 프로필은 페이지네이션을 쓰지 않는다
    }
}
