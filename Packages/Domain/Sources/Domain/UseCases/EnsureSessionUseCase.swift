import Foundation

/// 앱이 서버와 통신할 수 있는 상태를 보장한다 — 세션이 없으면 만들고, 있으면 그대로 쓴다.
///
/// 앱 진입마다 호출되므로 **이미 세션이 있을 때 네트워크를 타지 않아야 한다.**
/// 그 판단은 구현(Repository)이 한다.
public protocol EnsureSessionUseCase: Sendable {
    func execute() async throws -> UserSession
}

public struct DefaultEnsureSessionUseCase: EnsureSessionUseCase {
    private let repository: AuthRepository

    public init(repository: AuthRepository) {
        self.repository = repository
    }

    public func execute() async throws -> UserSession {
        try await repository.ensureSession()
    }
}
