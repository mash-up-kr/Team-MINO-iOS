import Domain
import Foundation
import MVITestSupport
@testable import ProfileSetupUI

/// 대부분의 케이스는 온보딩(create) 경로의 순수 State 판정을 본다 — 매번 같은 조립을 반복하지 않는다.
@MainActor
func makeCreateTestStore(
    _ state: ProfileSetupState = ProfileSetupState()
) -> TestStore<ProfileSetupState, ProfileSetupAction, ProfileSetupNav> {
    TestStore(state, reduce: profileSetupReducer(.create(register: StubRegisterProfileUseCase())))
}

/// 테스트용 프로필 고정값.
enum StubProfile {
    static func make(nickname: String = "꾹이", avatarColor: AvatarColor? = .red) -> Profile {
        Profile(id: "user-1", nickname: nickname, avatarColor: avatarColor, createdAt: nil)
    }
}

/// 호출 여부와 인자를 기록하는 등록 Stub. 실패를 주입하면 그 오류를 던진다.
final class StubRegisterProfileUseCase: RegisterProfileUseCase, @unchecked Sendable {
    private(set) var received: (nickname: String, avatarColor: AvatarColor)?
    private let error: DomainError?

    init(error: DomainError? = nil) {
        self.error = error
    }

    func execute(nickname: String, avatarColor: AvatarColor) async throws -> Profile {
        received = (nickname, avatarColor)
        if let error { throw error }
        return StubProfile.make(nickname: nickname, avatarColor: avatarColor)
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
    private(set) var received: (nickname: String?, avatarColor: AvatarColor?)?
    private let error: DomainError?

    init(error: DomainError? = nil) {
        self.error = error
    }

    func execute(nickname: String?, avatarColor: AvatarColor?) async throws -> Profile {
        received = (nickname, avatarColor)
        if let error { throw error }
        return StubProfile.make(nickname: nickname ?? "꾹이", avatarColor: avatarColor)
    }
}
