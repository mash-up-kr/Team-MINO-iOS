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

public struct DefaultRegisterProfileUseCase: RegisterProfileUseCase {
    private let repository: ProfileRepository

    public init(repository: ProfileRepository) {
        self.repository = repository
    }

    public func execute(nickname: String, avatarColor: AvatarColor) async throws -> Profile {
        try await repository.register(nickname: nickname, avatarColor: avatarColor)
    }
}

public struct DefaultFetchProfileUseCase: FetchProfileUseCase {
    private let repository: ProfileRepository

    public init(repository: ProfileRepository) {
        self.repository = repository
    }

    public func execute() async throws -> Profile {
        try await repository.me()
    }
}

public struct DefaultUpdateProfileUseCase: UpdateProfileUseCase {
    private let repository: ProfileRepository

    public init(repository: ProfileRepository) {
        self.repository = repository
    }

    public func execute(nickname: String?, avatarColor: AvatarColor?) async throws -> Profile {
        try await repository.update(nickname: nickname, avatarColor: avatarColor)
    }
}
