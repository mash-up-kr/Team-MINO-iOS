import Domain
import Foundation

/// `LastKnownProfileRepository` 의 메모리 구현. **앱 실행 하나만큼만 산다.**
///
/// 디스크(UserDefaults)에 남기지 않는 이유가 둘이다.
/// - 필요가 없다. 앱 시작이 메인 탭을 띄우기 전에 이미 `GET /users/me` 를 한 번 다녀오므로
///   (`AppLaunchStore.establishSession`), 탭이 그려질 시점엔 이 캐시가 채워져 있다.
/// - 남기면 **남의 이름이 뜰 수 있다.** 로그아웃 뒤 다른 계정으로 들어오면 첫 프레임에 이전
///   계정의 닉네임·아바타가 잠깐 그려진다 — 빈 화면보다 나쁜 오표시다.
///
/// `@unchecked Sendable`: 값을 락으로 감싸 직접 보호한다(쓰기는 네트워크 응답 스레드, 읽기는 MainActor).
public final class InMemoryLastKnownProfileRepository: LastKnownProfileRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var profile: Profile?

    public init() {}

    public func lastKnownProfile() -> Profile? {
        lock.lock()
        defer { lock.unlock() }
        return profile
    }

    public func save(_ profile: Profile) {
        lock.lock()
        defer { lock.unlock() }
        self.profile = profile
    }
}
