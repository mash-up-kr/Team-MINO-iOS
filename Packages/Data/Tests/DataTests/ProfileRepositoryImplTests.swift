import Domain
import Foundation
import Networking
import Testing
@testable import Data

/// 검증 대상은 **매핑과 에러 변환**이다 — 실제 HTTP 는 태우지 않는다(AddingAPI.md §7).
struct ProfileRepositoryImplTests {
    @Test("등록은 닉네임·아바타를 실어 보내고 응답을 Profile 로 옮긴다")
    func register_mapsResponse() async throws {
        let client = StubHTTPClient(result: .success(Self.dto(nickname: "민호", avatarColor: "pink")))
        let sut = ProfileRepositoryImpl(client: client)

        let profile = try await sut.register(nickname: "민호", avatarColor: .pink)

        #expect(profile.nickname == "민호")
        #expect(profile.avatarColor == .pink)
        #expect(await client.lastPath == "api/v1/users")
        #expect(await client.lastMethod == .post)
    }

    @Test("등록은 인증 미들웨어를 부분만 태운다 — full 이면 최초 진입이 막힌다")
    func register_usesUnregisteredUserAuth() async throws {
        let client = StubHTTPClient(result: .success(Self.dto()))
        _ = try await ProfileRepositoryImpl(client: client).register(nickname: "민호", avatarColor: .red)

        guard case .unregisteredUser = await client.lastAuth else {
            Issue.record("register 는 .unregisteredUser 여야 한다")
            return
        }
    }

    @Test("조회는 GET /me 를 친다")
    func me_hitsMeEndpoint() async throws {
        let client = StubHTTPClient(result: .success(Self.dto(nickname: "꾹이", avatarColor: "orange")))
        let profile = try await ProfileRepositoryImpl(client: client).me()

        #expect(profile.avatarColor == .orange)
        #expect(await client.lastPath == "api/v1/users/me")
        #expect(await client.lastMethod == .get)
    }

    @Test("수정은 PATCH 로 보낸다")
    func update_usesPatch() async throws {
        let client = StubHTTPClient(result: .success(Self.dto()))
        _ = try await ProfileRepositoryImpl(client: client).update(nickname: "민호", avatarColor: nil)

        #expect(await client.lastPath == "api/v1/users/me")
        #expect(await client.lastMethod == .patch)
    }

    @Test("아바타가 없는 계정도 읽을 수 있다 — 스펙상 nullable")
    func me_withoutAvatar() async throws {
        let client = StubHTTPClient(result: .success(Self.dto(avatarColor: nil)))
        let profile = try await ProfileRepositoryImpl(client: client).me()

        #expect(profile.avatarColor == nil)
    }

    // 아바타가 { id: Int } 이던 시절에 가입한 계정은 avatar 에 color 가 없다(실측).
    // 회원 삭제 API 가 없어 그 계정을 지울 수도 없는데, 여기서 깨지면 앱 진입이 막힌다.
    @Test("color 없는 avatar 도 읽는다 — 구 계약으로 가입한 계정")
    func me_withAvatarMissingColor() async throws {
        let client = StubHTTPClient(result: .success(ProfileDTO(
            id: "user-1", nickname: "꾹이", avatar: AvatarDTO(color: nil),
            createdAt: Date(timeIntervalSince1970: 0)
        )))
        let profile = try await ProfileRepositoryImpl(client: client).me()

        #expect(profile.avatarColor == nil)
        #expect(profile.nickname == "꾹이")
    }

    // 서버 팔레트가 우리보다 앞서 나갈 수 있다. 통째로 디코딩을 깨뜨리면 프로필 자체를 못 읽는다.
    @Test("모르는 색은 아바타 없음으로 떨어뜨린다 — 프로필 조회를 깨뜨리지 않는다")
    func me_withUnknownColor() async throws {
        let client = StubHTTPClient(result: .success(Self.dto(avatarColor: "chartreuse")))
        let profile = try await ProfileRepositoryImpl(client: client).me()

        #expect(profile.avatarColor == nil)
        #expect(profile.nickname == "꾹이")
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
        let client = StubHTTPClient(result: .failure(NetworkError.server(statusCode: 500)))
        await #expect(throws: DomainError.profileSaveFailed) {
            try await ProfileRepositoryImpl(client: client).register(nickname: "민호", avatarColor: .red)
        }
    }

    // 재설치하면 익명 세션이 Keychain 에 남아 같은 uid 로 돌아온다 — 그 사용자가 닿는 응답이다.
    // 저장 실패로 뭉개면 화면이 "다시 시도" 만 반복시켜 온보딩에 갇힌다.
    @Test("409 는 이미 등록됨으로 번역한다 — 저장 실패와 다르다")
    func conflict_mapsToAlreadyRegistered() async {
        let client = StubHTTPClient(result: .failure(
            NetworkError.conflict(code: "USER_ALREADY_REGISTERED", message: "이미 등록된 사용자입니다.")
        ))
        await #expect(throws: DomainError.alreadyRegistered) {
            try await ProfileRepositoryImpl(client: client).register(nickname: "민호", avatarColor: .red)
        }
    }

    // 서버는 미등록도 401 로 준다(404 가 아니다). errorCode 를 봐야 인증 실패와 갈린다 —
    // 뭉뚱그리면 최초 사용자가 온보딩 대신 재시도 화면에 갇힌다.
    @Test("401 + USER_NOT_REGISTERED 는 미등록으로 번역한다")
    func unregistered_mapsToNotRegistered() async {
        let client = StubHTTPClient(result: .failure(
            NetworkError.unauthorized(code: "USER_NOT_REGISTERED", message: "등록되지 않은 사용자입니다.")
        ))
        await #expect(throws: DomainError.notRegistered) {
            try await ProfileRepositoryImpl(client: client).me()
        }
    }

    @Test("취소는 실패가 아니다 — CancellationError 로 되돌린다")
    func cancellation_isNotFailure() async {
        let client = StubHTTPClient(result: .failure(NetworkError.cancelled))
        await #expect(throws: CancellationError.self) {
            try await ProfileRepositoryImpl(client: client).me()
        }
    }

    private static func dto(nickname: String = "꾹이", avatarColor: String? = "red") -> ProfileDTO {
        ProfileDTO(
            id: "user-1",
            nickname: nickname,
            avatar: avatarColor.map { AvatarDTO(color: $0) },
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

    // Domain 에도 Page 가 생겨(목록 API 공용 값 타입) 두 모듈을 함께 import 하는 이 파일에서는 모호하다.
    func requestPage<Element>(_ endpoint: PagedEndpoint<Element>) async throws -> Networking.Page<Element> {
        throw NetworkError.cancelled   // 프로필은 페이지네이션을 쓰지 않는다
    }
}
