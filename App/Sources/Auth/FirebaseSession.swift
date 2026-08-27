import Core
import FirebaseAuth
import FirebaseCore
import Logging

/// Firebase 초기화 + 세션 Keychain 그룹 지정. **본앱과 익스텐션이 함께 쓰는 파일**이다
/// (양쪽 타깃 멤버십). 둘 다 같은 그룹을 지정해야 서로의 세션이 보인다.
enum FirebaseSession {
    /// 프로세스 시작 시 **가장 먼저**, 사용자를 건드리기 전에 부른다.
    ///
    /// `useUserAccessGroup` 은 지정 시점의 로그인 사용자를 새 그룹으로 **이관**한다. 이 앱은
    /// 가입 절차 없는 익명 인증이라 세션이 곧 계정이고 `signOut` 을 부르지 않으므로
    /// (`FirebaseAuthRepository` 참조), 사용자를 쓴 뒤에 그룹을 바꾸면 이관 대상이 어긋난다.
    static func configure() {
        // 익스텐션 프로세스는 재사용될 수 있어 진입점이 두 번 불릴 수 있다.
        // `FirebaseApp.configure()` 는 두 번 부르면 예외를 던진다.
        guard FirebaseApp.app() == nil else { return }

        // Crashlytics 가 초기화 이후의 크래시만 잡으므로 가장 먼저 부른다.
        FirebaseApp.configure()

        do {
            try Auth.auth().useUserAccessGroup(SharedKeychain.accessGroup)
        } catch {
            // **반드시 기본 그룹으로 되돌린다.** 로그만 남기고 넘어가면 SDK 가 접근 권한 없는 그룹을
            // 계속 쓰려 해 **익명 로그인 자체가 실패한다**(`AuthErrorCodeKeychainError`, code 8).
            // 그러면 공유 기능 하나 때문에 앱 전체를 못 쓴다 — 실제로 재현했다.
            //
            // 되돌리면 익스텐션만 세션을 못 보고 본앱은 정상 동작한다. Keychain Sharing capability 가
            // 없는 프로비저닝(무료 Personal Team 등)으로 빌드하면 여기로 떨어진다.
            Log.error("Keychain 그룹 지정 실패 — 익스텐션이 세션을 보지 못한다", metadata: [
                "group": SharedKeychain.accessGroup,
                "reason": String(describing: error),
            ])
            try? Auth.auth().useUserAccessGroup(nil)
        }
    }
}
