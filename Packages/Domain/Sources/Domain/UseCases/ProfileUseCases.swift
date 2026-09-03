import Foundation

/// 프로필을 처음 만든다 — 온보딩 최초 진입에서 저장을 누른 결과다.
public protocol RegisterProfileUseCase: Sendable {
    func execute(nickname: String, avatarColor: AvatarColor) async throws -> Profile
}

/// 내 프로필을 읽는다 — 마이페이지에서 수정 화면에 들어설 때 현재 값을 채운다.
public protocol FetchProfileUseCase: Sendable {
    func execute() async throws -> Profile
}

/// 프로필을 고친다. 넘긴 항목만 바뀐다.
public protocol UpdateProfileUseCase: Sendable {
    func execute(nickname: String?, avatarColor: AvatarColor?) async throws -> Profile
}

/// 마지막으로 읽은 프로필을 **기다리지 않고** 꺼낸다 — 화면이 첫 프레임을 채우는 데 쓴다.
///
/// 서버에 묻지 않으므로 최신이라는 보장이 없다. 화면은 이 값으로 먼저 그리고,
/// ``FetchProfileUseCase`` 의 결과가 오면 조용히 갈아 끼운다.
///
/// > 권한 스위치에는 이 방식을 쓰지 않는다 — 스펙이 "로컬 캐시가 아니라 진입·복귀마다 재조회" 를
/// > 명시한다(mypage-settings FR-009). 여기서 기억하는 건 프로필(닉네임·아바타)뿐이다.
public protocol LastKnownProfileUseCase: Sendable {
    func execute() -> Profile?
}

/// 서버를 다녀온 프로필은 **한 곳에서** 기억한다.
///
/// 세 유스케이스(등록·조회·수정)가 모두 여기를 지나므로, 화면이 어느 경로로 프로필을 얻었든
/// 다음 진입의 첫 프레임이 채워진다. 화면마다 "받았으니 저장해 둬" 를 잊지 않고 부르는 규율에
/// 기대지 않으려고 유스케이스 안에 둔다.
private func remember(_ profile: Profile, in cache: LastKnownProfileRepository) -> Profile {
    cache.save(profile)
    return profile
}

public struct DefaultRegisterProfileUseCase: RegisterProfileUseCase {
    private let repository: ProfileRepository
    private let cache: LastKnownProfileRepository

    public init(repository: ProfileRepository, cache: LastKnownProfileRepository) {
        self.repository = repository
        self.cache = cache
    }

    public func execute(nickname: String, avatarColor: AvatarColor) async throws -> Profile {
        remember(try await repository.register(nickname: nickname, avatarColor: avatarColor), in: cache)
    }
}

public struct DefaultFetchProfileUseCase: FetchProfileUseCase {
    private let repository: ProfileRepository
    private let cache: LastKnownProfileRepository

    public init(repository: ProfileRepository, cache: LastKnownProfileRepository) {
        self.repository = repository
        self.cache = cache
    }

    public func execute() async throws -> Profile {
        remember(try await repository.me(), in: cache)
    }
}

public struct DefaultUpdateProfileUseCase: UpdateProfileUseCase {
    private let repository: ProfileRepository
    private let cache: LastKnownProfileRepository

    public init(repository: ProfileRepository, cache: LastKnownProfileRepository) {
        self.repository = repository
        self.cache = cache
    }

    public func execute(nickname: String?, avatarColor: AvatarColor?) async throws -> Profile {
        remember(try await repository.update(nickname: nickname, avatarColor: avatarColor), in: cache)
    }
}

public struct DefaultLastKnownProfileUseCase: LastKnownProfileUseCase {
    private let cache: LastKnownProfileRepository

    public init(cache: LastKnownProfileRepository) {
        self.cache = cache
    }

    public func execute() -> Profile? {
        cache.lastKnownProfile()
    }
}
