import Domain
import Logging
import Networking

/// Repository 들이 공유하는 반부패 계층 조각.
///
/// **상태코드 열거 자체는 각 Repository 에 남긴다** — 어떤 코드를 "예상한다" 고 선언하는 것이
/// 리소스마다 다르고, 나열되지 않은 코드가 로그로 드러나는 것이 이 규약의 신호 장치이기 때문이다
/// (`Packages/Networking/Docs/AddingAPI.md`). 여기 모으는 건 그 판단이 아니라 **판단이 같은 부분**이다.
extension NetworkError {
    /// 401 을 도메인 어휘로 나눈다.
    ///
    /// 서버는 **미등록도 401 로** 준다(404 가 아니다) — 둘을 가르는 건 `errorCode` 뿐이다.
    /// 인증이 깨진 것과 "아직 가입 전"은 사용자가 할 일이 완전히 달라(재로그인 vs 온보딩)
    /// 여기서 반드시 나눈다.
    var unauthorizedReason: DomainError {
        errorCode == NetworkError.userNotRegisteredCode ? .notRegistered : .unauthorized
    }

    /// 기기가 네트워크에 닿지 못한 실패인가.
    ///
    /// `.unknown` 은 제외한다 — TLS 실패까지 섞여 있어(`NetworkError.transport` 주석) 연결 문제라고
    /// 단정할 수 없다. 그런 건 부르는 쪽이 일시적 오류로 흡수한다.
    ///
    /// 프로필 조회(스플래시)와 초대 진입이 같은 판단을 하므로 여기 모은다 — 갈리면 한쪽만
    /// "연결을 확인해주세요" 를 띄우고 다른 쪽은 엉뚱한 안내를 하게 된다.
    var isNetworkUnavailable: Bool {
        if case .transport(let reason) = self { return reason != .unknown }
        return false
    }

    /// 번역하지 못했다는 사실을 남긴다 — 어떤 `DomainError` 를 추가해야 하는지 알 수 있는 유일한
    /// 단서다. 이 로그가 없으면 403·409·타임아웃이 전부 "알 수 없는 오류" 로 수렴하고 아무도
    /// 눈치채지 못한다.
    ///
    /// 오류는 `label`(케이스 이름)로만 남긴다 — `String(describing:)` 으로 통째로 찍으면 연관값의
    /// 서버 원문 message·본문 preview 가 릴리즈 기기 로그에 평문으로 남는다(Networking README §금지).
    func logUntranslated() {
        Log.warning("도메인으로 번역되지 않음", metadata: [
            "error": label,
            "status": statusCode.map(String.init) ?? "-",
            "code": errorCode ?? "-",
        ])
    }
}
