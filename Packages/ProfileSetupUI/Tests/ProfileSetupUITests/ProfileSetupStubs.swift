import Domain
import Foundation

/// 테스트용 프로필 고정값.
enum StubProfile {
    static func make(nickname: String = "꾹이", avatarIndex: Int? = 0) -> Profile {
        Profile(id: "user-1", nickname: nickname, avatarIndex: avatarIndex, createdAt: nil)
    }
}

/// 호출 여부와 인자를 기록하는 등록 Stub. 실패를 주입하면 그 오류를 던진다.
final class StubRegisterProfileUseCase: RegisterProfileUseCase, @unchecked Sendable {
    private(set) var received: (nickname: String, avatarIndex: Int)?
    private let error: DomainError?

    init(error: DomainError? = nil) {
        self.error = error
    }

    func execute(nickname: String, avatarIndex: Int) async throws -> Profile {
        received = (nickname, avatarIndex)
        if let error { throw error }
        return StubProfile.make(nickname: nickname, avatarIndex: avatarIndex)
    }
}

final class StubFetchProfileUseCase: FetchProfileUseCase, @unchecked Sendable {
    private let result: Result<Profile, DomainError>

    init(_ result: Result<Profile, DomainError> = .success(StubProfile.make())) {
        self.result = result
    }

    func execute() async throws -> Profile {
        try result.get()
    }
}

final class StubUpdateProfileUseCase: UpdateProfileUseCase, @unchecked Sendable {
    private(set) var received: (nickname: String?, avatarIndex: Int?)?
    private let error: DomainError?

    init(error: DomainError? = nil) {
        self.error = error
    }

    func execute(nickname: String?, avatarIndex: Int?) async throws -> Profile {
        received = (nickname, avatarIndex)
        if let error { throw error }
        return StubProfile.make(nickname: nickname ?? "꾹이", avatarIndex: avatarIndex)
    }
}
