import Testing
@testable import Domain

// MARK: - Test Doubles

private struct FakeProfileRepository: ProfileRepository {
    var profile: Profile
    var error: DomainError?

    func register(nickname: String, avatarColor: AvatarColor) async throws -> Profile {
        if let error { throw error }
        return Profile(id: profile.id, nickname: nickname, avatarColor: avatarColor, createdAt: nil)
    }

    func me() async throws -> Profile {
        if let error { throw error }
        return profile
    }

    func update(nickname: String?, avatarColor: AvatarColor?) async throws -> Profile {
        if let error { throw error }
        return Profile(
            id: profile.id,
            nickname: nickname ?? profile.nickname,
            avatarColor: avatarColor ?? profile.avatarColor,
            createdAt: profile.createdAt
        )
    }
}

private final class SpyLastKnownProfileRepository: LastKnownProfileRepository, @unchecked Sendable {
    private var profile: Profile?
    private(set) var saveCount = 0

    init(profile: Profile? = nil) { self.profile = profile }

    func lastKnownProfile() -> Profile? { profile }

    func save(_ profile: Profile) {
        self.profile = profile
        saveCount += 1
    }
}

private let fixture = Profile(id: "user-1", nickname: "홍길동", avatarColor: .pink, createdAt: nil)

// MARK: - Tests

/// 마이페이지의 첫 프레임은 **서버를 기다리지 않고** 마지막으로 알던 프로필로 그린다.
/// 그 값이 채워지는 자리가 여기다 — 화면이 "받았으니 저장해 둬" 를 부르는 규율에 기대지 않는다.
struct ProfileUseCaseTests {
    @Test("조회에 성공하면 마지막으로 알던 프로필로 기억한다")
    func fetchRemembersProfile() async throws {
        let cache = SpyLastKnownProfileRepository()
        let useCase = DefaultFetchProfileUseCase(
            repository: FakeProfileRepository(profile: fixture),
            cache: cache
        )

        let fetched = try await useCase.execute()

        #expect(fetched == fixture)
        #expect(cache.lastKnownProfile() == fixture)
    }

    @Test("등록에 성공하면 그 프로필을 기억한다 — 온보딩 직후 마이페이지가 비어 있지 않다")
    func registerRemembersProfile() async throws {
        let cache = SpyLastKnownProfileRepository()
        let useCase = DefaultRegisterProfileUseCase(
            repository: FakeProfileRepository(profile: fixture),
            cache: cache
        )

        _ = try await useCase.execute(nickname: "김유빈", avatarColor: .cyan)

        #expect(cache.lastKnownProfile()?.nickname == "김유빈")
        #expect(cache.lastKnownProfile()?.avatarColor == .cyan)
    }

    // 수정하고 돌아온 마이페이지가 **옛 이름**을 한 번 그렸다가 갈아 끼우면, 방금 저장한 것이
    // 반영되지 않은 것처럼 보인다.
    @Test("수정에 성공하면 새 값으로 기억한다")
    func updateRemembersNewProfile() async throws {
        let cache = SpyLastKnownProfileRepository(profile: fixture)
        let useCase = DefaultUpdateProfileUseCase(
            repository: FakeProfileRepository(profile: fixture),
            cache: cache
        )

        _ = try await useCase.execute(nickname: "김유빈", avatarColor: nil)

        #expect(cache.lastKnownProfile()?.nickname == "김유빈")
        #expect(cache.lastKnownProfile()?.avatarColor == .pink)   // 안 넘긴 항목은 그대로
    }

    // 실패한 조회로 기억을 덮으면, 다음 진입의 첫 프레임이 빈 값이 된다 — 알던 값을 잃지 않는다.
    @Test("조회에 실패하면 기억을 건드리지 않는다")
    func failedFetchKeepsPreviousMemory() async {
        let cache = SpyLastKnownProfileRepository(profile: fixture)
        let useCase = DefaultFetchProfileUseCase(
            repository: FakeProfileRepository(profile: fixture, error: .profileFetchFailed),
            cache: cache
        )

        _ = try? await useCase.execute()

        #expect(cache.saveCount == 0)
        #expect(cache.lastKnownProfile() == fixture)
    }

    @Test("아직 한 번도 못 읽었으면 마지막으로 알던 프로필이 없다")
    func lastKnownIsNilBeforeFirstFetch() {
        let useCase = DefaultLastKnownProfileUseCase(cache: SpyLastKnownProfileRepository())

        #expect(useCase.execute() == nil)
    }
}
