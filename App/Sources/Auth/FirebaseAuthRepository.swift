import Domain
import FirebaseAuth
import Foundation
import Logging

/// `AuthRepository` 의 Firebase 익명 인증 구현.
///
/// **가입 절차 없이** 사용자를 식별한다. 세션(refresh token)은 Firebase SDK 가 Keychain 에
/// 보관하므로 앱을 껐다 켜도, 지웠다 다시 깔아도 대체로 같은 UID 로 돌아온다.
/// 다만 기기를 바꾸거나 초기화하면 다른 사용자가 된다 — 익명 계정은 기기에 묶이고
/// 되찾을 수단이 없다. 그래서 **`signOut` 을 부르지 않는다**(부르는 순간 그 계정은 유실된다).
///
/// `Auth.auth()` 는 프로퍼티로 들지 않고 메서드 안에서 매번 얻는다. `AppDependencies` 가
/// `MINOApp.init()` 에서 만들어지는데 그게 `FirebaseApp.configure()`(AppDelegate)보다
/// 먼저 도는지 보장되지 않아, **Firebase 접촉을 전부 async 메서드 안으로 미루는** 것이다.
struct FirebaseAuthRepository: AuthRepository {
    /// 익명 로그인 상한. Firebase 는 네트워크가 죽으면 URLSession 기본값(60초)에 가깝게
    /// 매달리는데, 그동안 스플래시가 멈춰 있어 사용자는 앱이 죽은 걸로 본다.
    private static let signInTimeout: Duration = .seconds(15)

    private struct SignInTimedOut: Error {}

    func currentSession() async -> UserSession? {
        Auth.auth().currentUser.map { UserSession(userID: $0.uid) }
    }

    func ensureSession() async throws -> UserSession {
        // 이미 있으면 네트워크를 타지 않는다. 앱 진입마다 불리므로 이 분기가 평소 경로다.
        if let user = Auth.auth().currentUser {
            return UserSession(userID: user.uid)
        }

        do {
            let uid = try await withThrowingTaskGroup(of: String.self) { group in
                group.addTask {
                    try await Auth.auth().signInAnonymously().user.uid
                }
                group.addTask {
                    try await Task.sleep(for: Self.signInTimeout)
                    throw SignInTimedOut()
                }
                defer { group.cancelAll() }
                guard let first = try await group.next() else { throw SignInTimedOut() }
                return first
            }
            Log.info("익명 세션을 새로 만들었다", metadata: ["uid": String(uid.prefix(6))])
            return UserSession(userID: uid)
        } catch {
            Self.logFailure(error)
            // 최초 실행에 네트워크가 없으면 여기로 온다. 재시도가 의미 있는 실패라
            // `unauthorized`(서버가 거부) 와 구분해서 올린다.
            throw DomainError.sessionUnavailable
        }
    }

    private static func logFailure(_ error: Error) {
        let code = (error as NSError).code
        // 콘솔에서 익명 로그인을 켜지 않으면 이 코드로 즉사한다. 그냥 넘기면 원인 모를
        // 재시도 루프로만 보여서, 개발 중에 눈에 띄게 남긴다.
        if code == AuthErrorCode.operationNotAllowed.rawValue {
            Log.error("Firebase 콘솔에서 익명 로그인이 꺼져 있다 — Authentication → Sign-in method 확인")
            return
        }
        Log.warning("익명 로그인 실패", metadata: ["code": String(code)])
    }
}
